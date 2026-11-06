"""Private issuer for PS Management Desktop Offline."""
import argparse
import base64
import getpass
import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

DEFAULT_KEY = Path.home() / ".ps-desktop-licensing" / "issuer.pem"


def encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def generate_key(path: Path) -> str:
    if path.exists():
        raise FileExistsError("Issuer key already exists. Keep it to renew existing installs.")
    password = getpass.getpass("New issuer passphrase: ")
    if len(password) < 12 or password != getpass.getpass("Repeat passphrase: "):
        raise ValueError("Passphrases must match and contain at least 12 characters.")
    key = Ed25519PrivateKey.generate()
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.BestAvailableEncryption(password.encode("utf-8")),
    )
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as file:
        file.write(pem)
    return encode(key.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw,
    ))


def issue(key: Ed25519PrivateKey, device: str, days: int, issued: datetime) -> str:
    device = device.strip().upper()
    if not re.fullmatch(r"[0-9A-F]{32}", device):
        raise ValueError("Copy the 32-character device ID from the app.")
    if not 1 <= days <= 3650:
        raise ValueError("Duration must be between 1 and 3650 days.")
    body = json.dumps({
        "product": "ps-desktop-offline",
        "device": device,
        "iat": int(issued.timestamp()),
        "exp": int((issued + timedelta(days=days)).timestamp()),
    }, separators=(",", ":")).encode("utf-8")
    message = f"PS1.{encode(body)}"
    return f"{message}.{encode(key.sign(message.encode('ascii')))}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", type=Path, default=DEFAULT_KEY)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("init", help="Create the encrypted private key and print its public key.")
    create = commands.add_parser("issue", help="Issue an activation or renewal code.")
    create.add_argument("--device", required=True)
    create.add_argument("--days", required=True, type=int)
    args = parser.parse_args()
    try:
        if args.command == "init":
            print(generate_key(args.key))
        else:
            key = serialization.load_pem_private_key(
                args.key.read_bytes(), password=getpass.getpass("Issuer passphrase: ").encode("utf-8")
            )
            if not isinstance(key, Ed25519PrivateKey):
                raise ValueError("Expected an Ed25519 issuer key.")
            print(issue(key, args.device, args.days, datetime.now(timezone.utc)))
    except (OSError, ValueError, TypeError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
