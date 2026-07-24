{
  description = "K3s infrastructure dev environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-hooks.url = "github:cachix/git-hooks.nix";
    prefrio.url = "github:prefeitura-rio/flakes";
  };

  outputs =
    {
      flake-utils,
      git-hooks,
      nixpkgs,
      prefrio,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        pre-commit = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            ripsecrets.enable = true;
            terraform-format.enable = true;
            tflint.enable = true;
            check-tfvars = {
              enable = true;
              name = "check-unencrypted-tfvars";
              entry = "${prefrio.packages.${system}.prefrio}/bin/prefrio check-tfvars terraform\\.tfvars\\.json";
              language = "system";
              pass_filenames = false;
              always_run = true;
            };
          };
        };
      in
      {
        checks.pre-commit = pre-commit;

        devShells.default = pkgs.mkShell {
          inherit (pre-commit) shellHook;
          packages =
            [
              prefrio.packages.${system}.deps
              prefrio.packages.${system}.prefrio
              prefrio.packages.${system}.k3s
            ]
            ++ (with pkgs; [ ansible tflint ])
            ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.incus;
        };
      }
    );
}
