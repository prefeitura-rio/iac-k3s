from os import environ
from pathlib import Path
from subprocess import CompletedProcess, run as subprocess_run
from sys import exit, stderr
from typing import NoReturn


def sops_dir() -> Path:
    return Path(environ.get("K3S_SOPS_DIR", ".k3s"))


INFO = "\033[36m[→]\033[0m"
SUCCESS = "\033[32m[✓]\033[0m"
ERROR = "\033[31m[✗]\033[0m"
WARNING = "\033[33m[⚠]\033[0m"


def info(msg: str) -> None:
    print(f"{INFO} {msg}", file=stderr)


def success(msg: str) -> None:
    print(f"{SUCCESS} {msg}", file=stderr)


def error(msg: str) -> None:
    print(f"{ERROR} {msg}", file=stderr)


def warning(msg: str) -> None:
    print(f"{WARNING} {msg}", file=stderr)


def die(msg: str) -> NoReturn:
    error(msg)
    exit(1)


def run(
    cmd: list[str],
    *,
    capture: bool = False,
    check: bool = True,
    stdin: str | None = None,
    env: dict[str, str] | None = None,
) -> CompletedProcess[str]:
    return subprocess_run(
        cmd,
        text=True,
        capture_output=capture,
        check=check,
        input=stdin,
        env=env,
    )


def run_binary(
    cmd: list[str],
    *,
    capture: bool = False,
    check: bool = True,
    stdin: bytes | None = None,
) -> CompletedProcess[bytes]:
    return subprocess_run(
        cmd,
        capture_output=capture,
        check=check,
        input=stdin,
    )
