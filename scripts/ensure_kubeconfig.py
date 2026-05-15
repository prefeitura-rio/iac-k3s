#!/usr/bin/env python3
"""Fetch, patch, and encrypt the k3s kubeconfig from the Incus master node."""

import argparse

from pydantic import BaseModel

from .config import config
from .ensure_incus import ensure_incus
from .lib import die, info, run, run_binary, success


class Args(BaseModel):
    force: bool


def parse_args() -> Args:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument(
        "--force", action="store_true", help="Force kubeconfig re-fetch"
    )
    return Args.model_validate(vars(parser.parse_args()))


def kubeconfig_exists() -> bool:
    kubeconfig = config.paths["kubeconfig_sops"]
    return kubeconfig.exists() and kubeconfig.stat().st_size > 0


def fetch_and_encrypt(cluster_name: str, hostname: str) -> None:
    kubeconfig = config.paths["kubeconfig_sops"]

    info(f"Fetching kubeconfig from {cluster_name}-master...")
    config.paths["sops_dir"].mkdir(parents=True, exist_ok=True)

    pull = run(
        [
            "incus",
            "file",
            "pull",
            f"{cluster_name}-master/etc/rancher/k3s/k3s.yaml",
            "/dev/stdout",
        ],
        capture=True,
        check=False,
    )

    if pull.returncode != 0 or not pull.stdout.strip():
        die(f"Failed to pull kubeconfig from {cluster_name}-master")

    patched = pull.stdout.replace("127.0.0.1", hostname).encode()

    encrypt = run_binary(
        [
            "sops",
            "encrypt",
            "--input-type",
            "binary",
            "--output-type",
            "binary",
            "--filename-override",
            str(kubeconfig),
            "/dev/stdin",
        ],
        capture=True,
        stdin=patched,
    )

    _ = kubeconfig.write_bytes(encrypt.stdout)
    kubeconfig.chmod(0o600)

    verify = run(
        [
            "sops",
            "exec-file",
            str(kubeconfig),
            "kubectl --kubeconfig={} get nodes",
        ],
        capture=True,
        check=False,
    )
    if verify.returncode != 0:
        die("Kubeconfig fetched but cluster unreachable")

    success(f"Kubeconfig encrypted at {kubeconfig}")


def ensure_kubeconfig(force: bool) -> None:
    if force:
        config.paths["kubeconfig_sops"].unlink(missing_ok=True)

    if kubeconfig_exists():
        return

    ensure_incus(force=force)
    fetch_and_encrypt(config.CLUSTER_NAME, config.K3S_MASTER_HOSTNAME)


if __name__ == "__main__":
    args = parse_args()
    ensure_kubeconfig(force=args.force)
