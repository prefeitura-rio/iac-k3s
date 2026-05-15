import sys
from pathlib import Path
from typing import override

from pydantic import Field
from pydantic_settings import BaseSettings


class Config(BaseSettings):
    INCUS_SERVER_HOST: str = Field(default="", min_length=0)
    INCUS_SERVER_USER: str = Field(default="", min_length=0)
    CLUSTER_NAME: str = Field(default="", min_length=0)
    K3S_SOPS_DIR: Path = Field(default=Path(".k3s"))
    K3S_MASTER_HOSTNAME: str = Field(default="k3s-master", min_length=1)

    @override
    def model_post_init(self, __context: object) -> None:
        missing = [
            name
            for name in ("INCUS_SERVER_HOST", "INCUS_SERVER_USER", "CLUSTER_NAME")
            if not getattr(self, name)
        ]

        if not missing:
            return

        print(
            f"\033[31m[✗]\033[0m Missing required env vars: {', '.join(missing)} (run 'direnv allow')",
            file=sys.stderr,
        )

        sys.exit(1)

    @property
    def paths(self) -> dict[str, Path]:
        return {
            "sops_dir": self.K3S_SOPS_DIR,
            "kubeconfig_sops": self.K3S_SOPS_DIR / "kubeconfig.sops",
            "cache_incus": self.K3S_SOPS_DIR / ".cache-incus",
            "incus_token_sops": self.K3S_SOPS_DIR / "incus-token.sops",
        }


config = Config()
