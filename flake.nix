{
  description = "Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs =
            with pkgs;
            [
              ansible
              just
              kubectl
              kubernetes-helm
              nodejs_latest
              terraform
              (google-cloud-sdk.withExtraComponents (
                with google-cloud-sdk.components; [ gke-gcloud-auth-plugin ]
              ))
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
              incus
            ];
        };
      }
    );
}
