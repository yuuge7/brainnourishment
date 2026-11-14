"""Create, inspect, and export a local Android signing identity without logging secrets."""

import argparse
import base64
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KEYSTORE = "brain-nourishment-release.jks"
ALIAS = "brain-nourishment"


def find_keytool():
    candidates = [shutil.which("keytool")]
    if os.environ.get("JAVA_HOME"):
        candidates.append(str(Path(os.environ["JAVA_HOME"]) / "bin" / "keytool"))
    candidates.append("C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe")
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise RuntimeError("keytool was not found. Install a JDK and add its bin directory to PATH.")


def load_properties(root=ROOT):
    properties = {}
    for line in (root / "key.properties").read_text(encoding="utf-8").splitlines():
        if line.strip() and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            properties[key.strip()] = value.strip()
    required = {"storeFile", "storePassword", "keyAlias", "keyPassword"}
    if not required.issubset(properties) or not all(properties[key] for key in required):
        raise RuntimeError("key.properties is missing a signing field.")
    return properties


def generate(root=ROOT):
    destination = root / KEYSTORE
    properties_file = root / "key.properties"
    if destination.exists() or properties_file.exists():
        raise RuntimeError("Signing files already exist. Restore or back them up; they will never be overwritten.")
    password = secrets.token_urlsafe(48)
    environment = {**os.environ, "BRAIN_STORE_PASSWORD": password}
    with tempfile.TemporaryDirectory(prefix=".signing-", dir=root) as scratch:
        temporary_key = Path(scratch) / KEYSTORE
        result = subprocess.run([
            find_keytool(), "-genkeypair", "-noprompt", "-storetype", "JKS",
            "-keystore", str(temporary_key), "-alias", ALIAS,
            "-keyalg", "RSA", "-keysize", "4096", "-sigalg", "SHA256withRSA",
            "-validity", "10000", "-dname", "CN=Brain Nourishment, OU=Android, O=Brain Nourishment",
            "-storepass:env", "BRAIN_STORE_PASSWORD", "-keypass:env", "BRAIN_STORE_PASSWORD",
        ], env=environment, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError("keytool could not create the signing key. Check your JDK installation.")
        with destination.open("xb") as output:
            output.write(temporary_key.read_bytes())
        destination.chmod(0o600)
        with properties_file.open("x", encoding="utf-8", newline="\n") as output:
            output.write(
                "# Local signing credentials. Back up with the keystore; never commit.\n"
                f"storeFile={KEYSTORE}\nstorePassword={password}\n"
                f"keyAlias={ALIAS}\nkeyPassword={password}\n"
            )
        properties_file.chmod(0o600)
    inspect(root)
    print(f"Created {KEYSTORE} and key.properties in the project root. Passwords were not printed.")


def inspect(root=ROOT):
    properties = load_properties(root)
    environment = {**os.environ, "BRAIN_STORE_PASSWORD": properties["storePassword"]}
    result = subprocess.run([
        find_keytool(), "-list", "-v", "-keystore", str(root / properties["storeFile"]),
        "-alias", properties["keyAlias"], "-storepass:env", "BRAIN_STORE_PASSWORD",
    ], env=environment, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("The signing key could not be opened with key.properties.")
    # The certificate identity/fingerprints are public; passwords are never included.
    (root / "signing-key-info.txt").write_text(result.stdout, encoding="utf-8")
    for line in result.stdout.splitlines():
        if "SHA256:" in line or "Alias name:" in line or "Valid from:" in line:
            print(line.strip())


def export(root=ROOT):
    properties = load_properties(root)
    payload = {
        "ANDROID_KEYSTORE_BASE64": base64.b64encode((root / properties["storeFile"]).read_bytes()).decode("ascii"),
        "ANDROID_STORE_PASSWORD": properties["storePassword"],
        "ANDROID_KEY_ALIAS": properties["keyAlias"],
        "ANDROID_KEY_PASSWORD": properties["keyPassword"],
    }
    destination = root / "signing-secrets.json"
    with destination.open("w", encoding="utf-8", newline="\n") as output:
        json.dump(payload, output, indent=2)
        output.write("\n")
    destination.chmod(0o600)
    print("Wrote ignored signing-secrets.json. Add its four values as android-release environment secrets.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["generate", "info", "export"])
    args = parser.parse_args()
    try:
        {"generate": generate, "info": inspect, "export": export}[args.command]()
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
