import base64
from contextlib import redirect_stdout
from io import StringIO
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from tool import release, signing

SHA = 'a' * 40
PUBSPEC = 'name: brain_nourishment\nversion: 1.0.0+1\n'


def metadata(event='push', number=7, attempt=1):
    return release.version_metadata(PUBSPEC, 123, number, attempt, event, SHA,
        42 if event == 'pull_request' else None)


def run_details(event='push'):
    return {'id': 123, 'run_number': 7, 'run_attempt': 1, 'workflow_id': 99,
        'repository': {'full_name': 'owner/app'}, 'event': event, 'conclusion': 'success',
        'head_branch': 'main', 'head_repository': {'full_name': 'owner/app'}, 'head_sha': SHA}


class VersionTests(unittest.TestCase):
    def test_prepare_updates_only_the_runner_checkout_and_emits_version_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'pubspec.yaml').write_text(PUBSPEC)
            event = root / 'event.json'
            event.write_text(json.dumps({'ref': 'refs/heads/main', 'after': SHA}))
            outputs = root / 'outputs'
            environment = {'GITHUB_EVENT_PATH': str(event), 'GITHUB_EVENT_NAME': 'push',
                'GITHUB_RUN_ID': '123', 'GITHUB_RUN_NUMBER': '7', 'GITHUB_RUN_ATTEMPT': '1',
                'GITHUB_OUTPUT': str(outputs)}
            with patch.dict(os.environ, environment), patch.object(release, 'ROOT', root), \
                    patch.object(release, 'git', return_value=SHA + '\n'), redirect_stdout(StringIO()):
                release.prepare(SimpleNamespace(output=str(root / 'metadata.json')))
            self.assertIn('version: 1.0.7+8', (root / 'pubspec.yaml').read_text())
            self.assertIn('build_number=8', outputs.read_text())
            self.assertEqual(json.loads((root / 'metadata.json').read_text())['head_sha'], SHA)

    def test_each_run_increases_app_version_and_android_code(self):
        previous = None
        tags = set()
        for number in range(1, 2000):
            result = metadata(number=number)
            self.assertNotIn(result['tag'], tags)
            self.assertEqual(result['version'], f'1.0.{number}')
            if previous:
                self.assertGreater(result['build_number'], previous['build_number'])
            tags.add(result['tag'])
            previous = result

    def test_preview_is_identified_and_reruns_keep_the_same_version(self):
        result = metadata('pull_request')
        self.assertEqual(result['tag'], 'v1.0.7-pr.42')
        self.assertTrue(result['preview'])
        self.assertEqual(result['version'], metadata('pull_request', attempt=2)['version'])
        self.assertEqual(result['build_number'], metadata()['build_number'])

    def test_bad_versions_identity_and_android_overflow_are_rejected(self):
        for pubspec in ['version: 1.0\n', 'version: 1.0.0\n', 'version: 1.0.0+2100000000\n']:
            with self.assertRaises(ValueError):
                release.version_metadata(pubspec, 1, 1, 1, 'push', SHA)
        for parameters in [(0, 1, 1, 'push', SHA, None), (1, 1, 1, 'push', 'bad', None),
                (1, 1, 1, 'workflow_dispatch', SHA, None), (1, 1, 1, 'pull_request', SHA, None)]:
            with self.assertRaises(ValueError):
                release.version_metadata(PUBSPEC, *parameters)


class TrustBoundaryTests(unittest.TestCase):
    def test_only_successful_runs_from_this_workflow_are_publishable(self):
        run = run_details()
        event = {'id': 123, 'run_attempt': 1}
        release.validate_run(run, event, 'owner/app', 99)
        for key, value in [('workflow_id', 100), ('conclusion', 'failure'), ('event', 'workflow_dispatch'),
                ('head_branch', 'other'), ('run_attempt', 2)]:
            changed = {**run, key: value}
            with self.assertRaises(ValueError):
                release.validate_run(changed, event, 'owner/app', 99)

    def test_fork_prs_are_allowed_but_fork_pushes_are_not(self):
        run = run_details('pull_request')
        run['head_repository'] = {'full_name': 'contributor/app'}
        release.validate_run(run, {'id': 123, 'run_attempt': 1}, 'owner/app', 99)
        run['event'] = 'push'
        with self.assertRaises(ValueError):
            release.validate_run(run, {'id': 123, 'run_attempt': 1}, 'owner/app', 99)

    def test_package_requires_exact_metadata_and_only_expected_files(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for name in ['metadata.json', 'brain-nourishment.apk', 'brain-nourishment.aab']:
                (folder / name).write_bytes(b'nonempty')
            expected = metadata()
            release.validate_package(folder, expected, expected)
            with self.assertRaises(ValueError):
                release.validate_package(folder, {**expected, 'head_sha': 'b' * 40}, expected)
            (folder / 'unexpected.py').write_text('print("never run")')
            with self.assertRaises(ValueError):
                release.validate_package(folder, expected, expected)


class ChangelogTests(unittest.TestCase):
    def test_git_records_preserve_empty_and_multiline_bodies(self):
        raw = f'{SHA}\0feat: Memory grid\0Details\nBREAKING CHANGE: rule\n\0{SHA}\0fix: Timer\0\0'
        self.assertEqual(release.commit_records(raw), [(SHA, 'feat: Memory grid', 'Details\nBREAKING CHANGE: rule\n'),
            (SHA, 'fix: Timer', '')])
        self.assertEqual(release.commit_records(''), [])

    def test_commit_messages_are_grouped_and_escaped(self):
        notes = release.render_changelog([(SHA, 'feat: New warmup', ''), (SHA, 'fix(timer)!: Changed timer', ''),
            (SHA, '<script>@everyone [link](bad)', '')], 'owner/app', metadata(), 'v1.0.6')
        self.assertIn('## Features', notes)
        self.assertIn('## Breaking changes', notes)
        self.assertIn('&lt;script&gt;', notes)
        self.assertNotIn('@everyone', notes)
        self.assertIn('compare/v1.0.6...', notes)
        self.assertIn('android-build-run:123', notes)

    def test_preview_notes_identify_unreviewed_development_build(self):
        notes = release.render_changelog([], 'owner/app', metadata('pull_request'))
        self.assertIn('Preview of PR #42', notes)
        self.assertIn('disposable development key', notes)


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / 'pubspec.yaml').write_text(PUBSPEC)
        self.folder = self.root / 'package'
        self.folder.mkdir()
        self.meta = metadata()
        (self.folder / 'metadata.json').write_text(json.dumps(self.meta))
        for extension in ['apk', 'aab']:
            (self.folder / f'brain-nourishment.{extension}').write_bytes(b'public-package')
        event = self.root / 'event.json'
        event.write_text(json.dumps({'workflow_run': {'id': 123, 'run_attempt': 1}}))
        self.environment = patch.dict(os.environ, {'GITHUB_EVENT_PATH': str(event), 'GITHUB_REPOSITORY': 'owner/app', 'GH_TOKEN': 'test-only'})
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def api(self, path, optional=False):
        if '/actions/runs/' in path:
            return run_details()
        if '/actions/workflows/' in path:
            return {'id': 99}
        return None

    def test_creates_versioned_assets_changelog_and_checksums_without_overwrite_flags(self):
        def git(*args, **kwargs):
            if args[0] == 'show':
                return PUBSPEC
            return f'{SHA}\0feat: Fresh exercise\0\0' if args[0] == 'log' else ''
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'api', side_effect=self.api), \
                patch.object(release, 'git', side_effect=git), patch.object(release.subprocess, 'run') as command, redirect_stdout(StringIO()):
            release.publish(SimpleNamespace(artifacts=str(self.folder)))
        arguments = command.call_args.args[0]
        self.assertEqual(arguments[:4], ['gh', 'release', 'create', 'v1.0.7'])
        self.assertNotIn('--clobber', arguments)
        self.assertTrue((self.folder / 'brain-nourishment-v1.0.7.apk').exists())
        self.assertIn('Fresh exercise', (self.folder / 'CHANGELOG.md').read_text(encoding='utf-8'))
        self.assertIn('brain-nourishment-v1.0.7.aab', (self.folder / 'SHA256SUMS.txt').read_text())

    def test_rerun_skips_its_existing_release_without_mutation(self):
        def api(path, optional=False):
            if '/releases/tags/' in path:
                return {'body': '<!-- android-build-run:123 -->'}
            return self.api(path, optional)
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'api', side_effect=api), \
                patch.object(release, 'git', return_value=PUBSPEC), patch.object(release.subprocess, 'run') as command, redirect_stdout(StringIO()):
            release.publish(SimpleNamespace(artifacts=str(self.folder)))
        command.assert_not_called()
        self.assertTrue((self.folder / 'brain-nourishment.apk').exists())

    def test_existing_release_from_another_run_is_never_reused(self):
        def api(path, optional=False):
            return {'body': 'some other release'} if '/releases/tags/' in path else self.api(path, optional)
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'api', side_effect=api), \
                patch.object(release, 'git', return_value=PUBSPEC), patch.object(release.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'Refusing to overwrite'):
                release.publish(SimpleNamespace(artifacts=str(self.folder)))
        command.assert_not_called()

    def test_fork_preview_has_separate_release_flags_and_no_bundle(self):
        preview = metadata('pull_request')
        (self.folder / 'metadata.json').write_text(json.dumps(preview))
        (self.folder / 'brain-nourishment.aab').unlink()
        def api(path, optional=False):
            if '/actions/runs/' in path:
                run = run_details('pull_request')
                run['head_repository'] = {'full_name': 'contributor/app'}
                return run
            if '/commits/' in path:
                return [{'number': 42, 'base': {'ref': 'main', 'sha': 'b' * 40, 'repo': {'full_name': 'owner/app'}}}]
            return self.api(path, optional)
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'api', side_effect=api), \
                patch.object(release, 'git', side_effect=lambda *args: PUBSPEC if args[0] == 'show' else ''), patch.object(release.subprocess, 'run') as command, redirect_stdout(StringIO()):
            release.publish(SimpleNamespace(artifacts=str(self.folder)))
        arguments = command.call_args.args[0]
        self.assertIn('--prerelease', arguments)
        self.assertIn('--latest=false', arguments)
        self.assertFalse(any(str(value).endswith('.aab') for value in arguments))

    def test_forged_pr_claim_is_rejected_before_any_publish_command(self):
        (self.folder / 'metadata.json').write_text(json.dumps(metadata('pull_request')))
        def api(path, optional=False):
            if '/actions/runs/' in path:
                return run_details('pull_request')
            if '/commits/' in path:
                return []
            return self.api(path, optional)
        with patch.object(release, 'ROOT', self.root), patch.object(release, 'api', side_effect=api), \
                patch.object(release.subprocess, 'run') as command:
            with self.assertRaisesRegex(ValueError, 'not associated'):
                release.publish(SimpleNamespace(artifacts=str(self.folder)))
        command.assert_not_called()


class SigningTests(unittest.TestCase):
    def test_existing_key_is_never_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / signing.KEYSTORE).write_bytes(b'original-key')
            with self.assertRaises(RuntimeError):
                signing.generate(root)
            self.assertEqual((root / signing.KEYSTORE).read_bytes(), b'original-key')

    def test_export_contains_restorable_key_and_does_not_print_passwords(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / signing.KEYSTORE).write_bytes(b'keystore-bytes')
            (root / 'key.properties').write_text(f'storeFile={signing.KEYSTORE}\nstorePassword=private-value\nkeyAlias=app\nkeyPassword=private-value\n')
            output = StringIO()
            with redirect_stdout(output):
                signing.export(root)
            exported = json.loads((root / 'signing-secrets.json').read_text())
            self.assertEqual(base64.b64decode(exported['ANDROID_KEYSTORE_BASE64']), b'keystore-bytes')
            self.assertEqual(exported['ANDROID_STORE_PASSWORD'], 'private-value')
            self.assertNotIn('private-value', output.getvalue())


if __name__ == '__main__':
    unittest.main()
