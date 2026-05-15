#!/usr/bin/env python3
"""Ensure Incus remote is configured with a valid encrypted token."""

import argparse
import shutil
import socket
import subprocess
import time
from pathlib import Path

from pydantic import BaseModel

from .config import config
from .lib import die, info, run, run_binary, success, warning

CACHE_TTL_MINUTES = 60


class Args(BaseModel):
    force: bool


def parse_args() -> Args:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument(
        "--force", action="store_true", help="Force token regeneration"
    )
    return Args.model_validate(vars(parser.parse_args()))


def cache_is_fresh() -> bool:
    if not config.paths["cache_incus"].exists():
        return False
    age_minutes = (time.time() - config.paths["cache_incus"].stat().st_mtime) / 60
    return age_minutes < CACHE_TTL_MINUTES


def machine_id() -> str:
    for path in [Path("/etc/machine-id"), Path("/var/lib/dbus/machine-id")]:
        if path.exists():
            return path.read_text().strip()
    return socket.gethostname()


def client_name() -> str:
    mid = machine_id()[:8]
    return f"{socket.gethostname()}-{mid}"


def ssh_run(
    user: str, host: str, remote_cmd: str, *, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    return run(
        [
            "ssh",
            "-o",
            "ConnectTimeout=10",
            "-o",
            "StrictHostKeyChecking=accept-new",
            f"{user}@{host}",
            remote_cmd,
        ],
        capture=capture,
        check=False,
    )


def ensure_incus(force: bool) -> None:
    if not shutil.which("incus"):
        warning("incus not installed — skipping remote configuration")
        return

    if force:
        config.paths["incus_token_sops"].unlink(missing_ok=True)
        config.paths["cache_incus"].unlink(missing_ok=True)

    if cache_is_fresh():
        return

    name = client_name()

    config.paths["incus_token_sops"].unlink(missing_ok=True)
    info(f"Generating Incus token for {name} via {config.INCUS_SERVER_HOST}...")

    _ = ssh_run(
        config.INCUS_SERVER_USER,
        config.INCUS_SERVER_HOST,
        f"incus config trust revoke-token {name}",
    )

    result = ssh_run(
        config.INCUS_SERVER_USER,
        config.INCUS_SERVER_HOST,
        f"incus config trust add {name}",
        capture=True,
    )
    token = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ""

    if not token or len(token) < 32:
        die(f"Failed to obtain a valid token from {config.INCUS_SERVER_HOST}")

    config.paths["sops_dir"].mkdir(parents=True, exist_ok=True)

    encrypt = run_binary(
        [
            "sops",
            "encrypt",
            "--input-type",
            "binary",
            "--output-type",
            "binary",
            "--filename-override",
            str(config.paths["incus_token_sops"]),
            "/dev/stdin",
        ],
        capture=True,
        stdin=token.encode(),
    )

    _ = config.paths["incus_token_sops"].write_bytes(encrypt.stdout)
    _ = config.paths["incus_token_sops"].chmod(0o600)

    _ = run(
        [
            "incus",
            "remote",
            "add",
            "k3s",
            f"{config.INCUS_SERVER_HOST}:8443",
            "--accept-certificate",
            f"--token={token}",
        ],
        check=False,
    )
    _ = run(["incus", "remote", "switch", "k3s"])

    _ = config.paths["cache_incus"].touch()
    success("Incus client configured")


if __name__ == "__main__":
    args = parse_args()
    ensure_incus(force=args.force)
