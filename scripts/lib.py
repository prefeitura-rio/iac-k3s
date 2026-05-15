import subprocess
import sys
from typing import NoReturn


INFO = "\033[36m[→]\033[0m"
SUCCESS = "\033[32m[✓]\033[0m"
ERROR = "\033[31m[✗]\033[0m"
WARNING = "\033[33m[⚠]\033[0m"


def info(msg: str) -> None:
    print(f"{INFO} {msg}", file=sys.stderr)


def success(msg: str) -> None:
    print(f"{SUCCESS} {msg}", file=sys.stderr)


def error(msg: str) -> None:
    print(f"{ERROR} {msg}", file=sys.stderr)


def warning(msg: str) -> None:
    print(f"{WARNING} {msg}", file=sys.stderr)


def die(msg: str) -> NoReturn:
    error(msg)
    sys.exit(1)


def run(
    cmd: list[str],
    *,
    capture: bool = False,
    check: bool = True,
    stdin: str | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
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
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        cmd,
        capture_output=capture,
        check=check,
        input=stdin,
    )
