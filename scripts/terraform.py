#!/usr/bin/env python3
"""Run a Terraform command with kubeconfig and secrets injected at runtime."""

from dataclasses import dataclass
from os import environ
from pathlib import Path
from sys import argv
from tempfile import NamedTemporaryFile
from typing import Literal, TypeGuard, get_args

from .lib import die, info, run, run_binary, sops_dir, success, warning

Command = Literal["apply", "destroy", "import"]
COMMANDS: tuple[Command, ...] = get_args(Command)


@dataclass
class Args:
    command: Command
    extra: list[str]


def is_command(value: str) -> TypeGuard[Command]:
    return value in COMMANDS



def parse_args() -> Args:
    args = argv[1:]

    if not args:
        die(f"Usage: terraform.py [{' | '.join(COMMANDS)}] [extra...]")

    raw = args[0]

    if not is_command(raw):
        die(f"Unknown command '{raw}'. Expected one of: {', '.join(COMMANDS)}")

    return Args(command=raw, extra=args[1:])


def decrypt_incus_token() -> str:
    incus_token_sops = sops_dir() / "incus-token.sops"
    result = run_binary(
        [
            "sops",
            "decrypt",
            "--output-type",
            "binary",
            str(incus_token_sops),
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


def terraform_run(command: Command, extra: list[str], tfdir: Path) -> None:
    kubeconfig_sops = sops_dir() / "kubeconfig.sops"
    tfvars_sops = tfdir / "terraform.tfvars.sops.json"
    incus_token = decrypt_incus_token()
    tfvars_json = decrypt_tfvars(tfvars_sops)

    with NamedTemporaryFile(mode="w", suffix=".json", delete=False) as tfvars_file:
        tfvars_path = Path(tfvars_file.name)
        _ = tfvars_file.write(tfvars_json)

    try:
        sops_cmd = (
            f"KUBECONFIG={{}} terraform -chdir={tfdir} {command}"
            f" -var-file={tfvars_path}"
            f" -var=kubeconfig_path={{}}"
            f" -var=incus_token=$TF_INCUS_TOKEN"
            f" {' '.join(extra)}"
        ).strip()

        env = {**environ, "TF_INCUS_TOKEN": incus_token}

        match command:
            case "apply":
                info("Applying Terraform changes...")
            case "destroy":
                warning("Running Terraform destroy...")
            case "import":
                info(f"Importing resource: {' '.join(extra)}")

        _ = run(
            ["sops", "exec-file", "--no-fifo", str(kubeconfig_sops), sops_cmd],
            env=env,
        )

        if command != "destroy":
            success(f"{command.capitalize()} completed")
            return

        success("Destroy completed")

    finally:
        tfvars_path.unlink(missing_ok=True)


if __name__ == "__main__":
    args = parse_args()
    terraform_run(args.command, args.extra, Path("terraform"))
