"""Deterministic build versions and trusted GitHub release publication (stdlib only)."""

import argparse
import base64
import hashlib
import html
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = "Brain Nourishment"
ARTIFACT_NAME = "brain-nourishment"
WORKFLOW = "android-build.yml"
VERSION_RE = re.compile(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$", re.MULTILINE)
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def version_metadata(pubspec, run_id, run_number, attempt, event, head_sha, pr_number=None):
    match = VERSION_RE.search(pubspec)
    if not match:
        raise ValueError("pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD")
    major, minor, patch, baseline_build = map(int, match.groups())
    if min(run_id, run_number, attempt) < 1 or not SHA_RE.fullmatch(head_sha):
        raise ValueError("Invalid workflow run identity or source commit.")
    if event not in ("push", "pull_request"):
        raise ValueError("Only main pushes and pull requests can produce releases.")
    if event == "pull_request" and (not isinstance(pr_number, int) or pr_number < 1):
        raise ValueError("A pull request number is required for previews.")
    if event == "push" and pr_number is not None:
        raise ValueError("Stable builds cannot contain a pull request number.")
    version = f"{major}.{minor}.{patch + run_number}"
    if pr_number is not None:
        version += f"-pr.{pr_number}"
    build_number = baseline_build + run_number
    if build_number > 2_100_000_000:
        raise ValueError("Android versionCode would exceed the supported limit.")
    return {
        "schema": 1, "run_id": run_id, "run_number": run_number,
        "run_attempt": attempt, "event": event, "head_sha": head_sha,
        "pr_number": pr_number, "version": version, "build_number": build_number,
        "tag": f"v{version}", "preview": pr_number is not None,
    }


def prepare(args):
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    event_name = os.environ["GITHUB_EVENT_NAME"]
    if event_name == "push":
        if event.get("ref") != "refs/heads/main" or event.get("deleted"):
            raise ValueError("Only non-deletion pushes to main can be released.")
        source_sha, pr_number = event["after"], None
    elif event_name == "pull_request":
        pull_request = event["pull_request"]
        source_sha, pr_number = pull_request["head"]["sha"], event["number"]
    else:
        raise ValueError("Unsupported build event.")
    pubspec_path = ROOT / "pubspec.yaml"
    pubspec = pubspec_path.read_text(encoding="utf-8")
    metadata = version_metadata(pubspec, int(os.environ["GITHUB_RUN_ID"]),
        int(os.environ["GITHUB_RUN_NUMBER"]), int(os.environ["GITHUB_RUN_ATTEMPT"]),
        event_name, source_sha, pr_number)
    if git("rev-parse", "HEAD").strip() != source_sha:
        raise ValueError("Checked-out source does not match the build event.")
    # This changes only the disposable runner checkout. No bot commits or pushes.
    pubspec_path.write_text(VERSION_RE.sub(
        f"version: {metadata['version']}+{metadata['build_number']}", pubspec, count=1), encoding="utf-8")
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
        for key in ("version", "build_number", "tag"):
            handle.write(f"{key}={metadata[key]}\n")
    print(f"Build version: {metadata['version']}+{metadata['build_number']}")


def git(*arguments, check=True):
    environment = os.environ.copy()
    if arguments and arguments[0] == "fetch" and environment.get("GH_TOKEN"):
        # Authenticate private-repository fetches without persisting credentials
        # or including tokens in process arguments/remote URLs.
        authorization = base64.b64encode(f"x-access-token:{environment['GH_TOKEN']}".encode()).decode()
        environment.update({"GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "http.https://github.com/.extraheader",
            "GIT_CONFIG_VALUE_0": f"AUTHORIZATION: basic {authorization}"})
    return subprocess.run(["git", *arguments], cwd=ROOT, check=check,
        capture_output=True, text=True, encoding="utf-8", env=environment).stdout


def api(path, optional=False):
    request = urllib.request.Request(f"https://api.github.com/{path}", headers={
        "Authorization": f"Bearer {os.environ['GH_TOKEN']}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "brain-nourishment-release",
    })
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if optional and error.code == 404:
            return None
        raise RuntimeError(f"GitHub API request failed ({error.code}): {path}") from None


def validate_run(run, event_run, repository, workflow_id):
    if run["id"] != event_run["id"] or run["run_attempt"] != event_run["run_attempt"]:
        raise ValueError("Stale completion event; the source workflow has been rerun.")
    if run["workflow_id"] != workflow_id or run["repository"]["full_name"] != repository:
        raise ValueError("Artifact source is not this repository's Android build workflow.")
    if run["conclusion"] != "success" or run["event"] not in ("push", "pull_request"):
        raise ValueError("Only successful Android push/PR builds may be published.")
    if not SHA_RE.fullmatch(run["head_sha"]):
        raise ValueError("The source workflow commit is invalid.")
    if run["event"] == "push" and (run["head_branch"] != "main" or
            run["head_repository"]["full_name"] != repository):
        raise ValueError("Stable releases must originate from this repository's main branch.")


def validate_package(folder, metadata, expected):
    if metadata != expected:
        raise ValueError("Artifact metadata does not match the independently verified workflow run.")
    expected_names = {"metadata.json", f"{ARTIFACT_NAME}.apk"}
    if not expected["preview"]:
        expected_names.add(f"{ARTIFACT_NAME}.aab")
    entries = list(folder.iterdir())
    if {entry.name for entry in entries} != expected_names:
        raise ValueError("Unexpected files in the release artifact.")
    for entry in entries:
        if entry.is_symlink() or not entry.is_file() or entry.stat().st_size == 0:
            raise ValueError("Release artifacts must be nonempty regular files.")
        if entry.stat().st_size > 1024 * 1024 * 1024:
            raise ValueError("An artifact exceeds the one-gigabyte limit.")


def commit_records(raw):
    # Remove only the record terminator: an empty final commit body is valid.
    fields = (raw[:-1] if raw.endswith("\0") else raw).split("\0") if raw else []
    if len(fields) % 3:
        raise ValueError("Unexpected git log format.")
    return [tuple(fields[index:index + 3]) for index in range(0, len(fields), 3)]


def render_changelog(records, repository, metadata, previous=None):
    groups = {name: [] for name in ["Breaking changes", "Features", "Fixes", "Performance",
        "Refactoring", "Documentation", "Tests", "Build and automation", "Other changes"]}
    categories = {"feat": "Features", "fix": "Fixes", "perf": "Performance", "refactor": "Refactoring",
        "docs": "Documentation", "test": "Tests", "build": "Build and automation", "ci": "Build and automation"}
    for sha, subject, body in records:
        conventional = re.match(r"([a-z]+)(?:\([^\n)]+\))?(!)?:\s*(.+)", subject)
        breaking = (conventional and conventional[2]) or "BREAKING CHANGE:" in body or "BREAKING-CHANGE:" in body
        category = "Breaking changes" if breaking else categories.get(conventional[1] if conventional else "", "Other changes")
        # Commit text is data: escape Markdown/HTML and never interpolate it into shell code.
        subject = html.escape(subject[:1000])
        subject = re.sub(r"([\\`*_{}\[\]()#+!|>])", r"\\\1", subject)
        subject = subject.replace("@", "&#64;")
        groups[category].append(f"- {subject} ([{sha[:7]}](https://github.com/{repository}/commit/{sha}))")
    version = metadata["version"]
    lines = [f"# Changelog — {APP_NAME} v{version}", ""]
    if metadata["preview"]:
        lines += [f"Preview of PR #{metadata['pr_number']}. Built from unreviewed pull-request code.",
            "Signed with a disposable development key; installs separately from the stable app.", ""]
    for category, items in groups.items():
        if items:
            lines += [f"## {category}", "", *items, ""]
    if not records:
        lines += ["No new commit messages in this comparison range.", ""]
    if previous:
        lines += [f"[Full comparison](https://github.com/{repository}/compare/{previous}...{metadata['head_sha']})", ""]
    lines += [f"Android version: `{version}+{metadata['build_number']}`.",
        f"[Build run](https://github.com/{repository}/actions/runs/{metadata['run_id']}) · Source: `{metadata['head_sha']}`.",
        "", f"<!-- android-build-run:{metadata['run_id']} -->", ""]
    return "\n".join(lines)


def publish(args):
    repository = os.environ["GITHUB_REPOSITORY"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Invalid repository name.")
    event_run = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))["workflow_run"]
    run = api(f"repos/{repository}/actions/runs/{event_run['id']}")
    workflow = api(f"repos/{repository}/actions/workflows/{WORKFLOW}")
    validate_run(run, event_run, repository, workflow["id"])
    folder = Path(args.artifacts).resolve()
    metadata_path = folder / "metadata.json"
    if metadata_path.is_symlink() or metadata_path.stat().st_size > 4096:
        raise ValueError("Invalid artifact metadata file.")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    pr_number = metadata.get("pr_number") if run["event"] == "pull_request" else None
    previous = None
    if run["event"] == "pull_request":
        if type(pr_number) is not int or pr_number < 1:
            raise ValueError("Invalid pull request identity.")
        # Fork workflow_run payloads can omit pull_requests, so verify association
        # through GitHub's commit-to-PR API rather than trusting artifact claims.
        associated = api(f"repos/{repository}/commits/{run['head_sha']}/pulls?per_page=100")
        candidates = [item for item in associated if item["number"] == pr_number
            and item["base"]["repo"]["full_name"] == repository]
        if not candidates:
            raise ValueError("The source commit is not associated with the claimed pull request to this repository.")
        previous = candidates[0]["base"]["sha"]
    git("fetch", "origin", run["head_sha"])
    # Read the baseline as inert text from the exact built commit. A newer main
    # commit may have changed its baseline while this build was still running.
    built_pubspec = git("show", f"{run['head_sha']}:pubspec.yaml")
    expected = version_metadata(built_pubspec, run["id"],
        run["run_number"], run["run_attempt"], run["event"], run["head_sha"], pr_number)
    validate_package(folder, metadata, expected)
    tag = metadata["tag"]
    existing = api(f"repos/{repository}/releases/tags/{tag}", optional=True)
    if existing is not None:
        if f"<!-- android-build-run:{run['id']} -->" in (existing.get("body") or ""):
            print(f"{tag} was already published by this build. No release or asset was changed.")
            return
        raise ValueError(f"Release {tag} already exists. Refusing to overwrite it; increase the pubspec version baseline.")
    if api(f"repos/{repository}/git/ref/tags/{tag}", optional=True) is not None:
        raise ValueError(f"Tag {tag} already exists. Refusing to reuse it.")
    if previous:
        git("fetch", "origin", previous)
    else:
        tags = git("tag", "--merged", run["head_sha"], "--sort=-version:refname").splitlines()
        previous = next((item for item in tags if re.fullmatch(r"v\d+\.\d+\.\d+", item)), None)
    revision_range = f"{previous}..{run['head_sha']}" if previous else run["head_sha"]
    raw = git("log", "--no-merges", "-z", "--format=%H%x00%s%x00%b", revision_range)
    changelog = folder / "CHANGELOG.md"
    changelog.write_text(render_changelog(commit_records(raw), repository, metadata, previous), encoding="utf-8")
    assets = []
    for extension in ("apk", "aab"):
        source = folder / f"{ARTIFACT_NAME}.{extension}"
        if source.exists():
            destination = folder / f"{ARTIFACT_NAME}-{tag}.{extension}"
            source.rename(destination)
            assets.append(destination)
    assets += [changelog, metadata_path]
    checksums = folder / "SHA256SUMS.txt"
    with checksums.open("w", encoding="utf-8", newline="\n") as output:
        for asset in assets:
            with asset.open("rb") as content:
                digest = hashlib.file_digest(content, "sha256").hexdigest()
            output.write(f"{digest}  {asset.name}\n")
    assets.append(checksums)
    command = ["gh", "release", "create", tag, *map(str, assets), "--repo", repository,
        "--target", run["head_sha"], "--title", f"{APP_NAME} v{metadata['version']}", "--notes-file", str(changelog)]
    if metadata["preview"]:
        command += ["--prerelease", "--latest=false"]
    subprocess.run(command, check=True)
    print(f"Created {APP_NAME} v{metadata['version']} with commit-based changelog and checksums.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    prepare_parser = subparsers.add_parser("prepare")
    prepare_parser.add_argument("--output", required=True)
    publish_parser = subparsers.add_parser("publish")
    publish_parser.add_argument("--artifacts", required=True)
    args = parser.parse_args()
    try:
        {"prepare": prepare, "publish": publish}[args.command](args)
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        # Do not dump environment variables or HTTP authorization headers.
        parser.exit(1, f"Release failed: {error}\n")


if __name__ == "__main__":
    main()
