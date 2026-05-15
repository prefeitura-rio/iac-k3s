#!/usr/bin/env python3
"""Run a Terraform command with kubeconfig and secrets injected at runtime."""

import argparse
import os
import tempfile
from pathlib import Path

from pydantic import BaseModel

from .config import config
from .lib import die, info, run, run_binary, success, warning


class Args(BaseModel):
    command: str
    extra: list[str]


def parse_args() -> Args:
    parser = argparse.ArgumentParser(description=__doc__)
    _ = parser.add_argument(
        "command",
        choices=["apply", "destroy", "import"],
        help="Terraform command to run",
    )
    _ = parser.add_argument(
        "extra",
        nargs="*",
        help="Extra positional args forwarded to terraform (e.g. ADDRESS ID for import)",
    )
    return Args.model_validate(vars(parser.parse_args()))


def decrypt_incus_token() -> str:
    result = run_binary(
        [
            "sops",
            "decrypt",
            "--output-type",
            "binary",
            str(config.paths["incus_token_sops"]),
        ],
        capture=True,
    )
    token = result.stdout.strip().decode()

    if not token:
        die("Failed to decrypt Incus token — run: just rotate-incus-token")

    return token


def decrypt_tfvars(tfvars_sops: Path) -> str:
    result = run(
        ["sops", "decrypt", "--output-type", "json", str(tfvars_sops)],
        capture=True,
    )

    if not result.stdout.strip():
        die(f"Failed to decrypt {tfvars_sops}")

    return result.stdout


def terraform_run(command: str, extra: list[str], tfdir: Path) -> None:
    kubeconfig_sops = config.paths["kubeconfig_sops"]
    tfvars_sops = tfdir / "terraform.tfvars.json.sops"

    incus_token = decrypt_incus_token()
    tfvars_json = decrypt_tfvars(tfvars_sops)

    # Write tfvars to a temp file that persists for the duration of the subprocess.
    # delete=False so the file survives the `with` block; we clean it up manually.
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False
    ) as tfvars_file:
        tfvars_path = Path(tfvars_file.name)
        _ = tfvars_file.write(tfvars_json)

    try:
        extra_args = " ".join(extra)

        # sops exec-file replaces every literal `{}` with the decrypted file path.
        # We use `{}` for the kubeconfig path and pass incus_token + tfvars_path
        # via the environment to avoid shell-quoting issues.
        sops_cmd = (
            f"KUBECONFIG={{}} terraform -chdir={tfdir} {command}"
            f" -var-file={tfvars_path}"
            f" -var=kubeconfig_path={{}}"
            f" -var=incus_token=$TF_INCUS_TOKEN"
            f" {extra_args}"
        ).strip()

        env = {**os.environ, "TF_INCUS_TOKEN": incus_token}

        if command == "apply":
            info("Applying Terraform changes...")
        elif command == "destroy":
            warning("Running Terraform destroy...")
        elif command == "import":
            info(f"Importing resource: {' '.join(extra)}")

        _ = run(
            ["sops", "exec-file", "--no-fifo", str(kubeconfig_sops), sops_cmd],
            env=env,
        )

        if command == "destroy":
            success("Destroy completed")
        else:
            success(f"{command.capitalize()} completed")

    finally:
        tfvars_path.unlink(missing_ok=True)


if __name__ == "__main__":
    args = parse_args()
    terraform_run(args.command, args.extra, Path("terraform"))
