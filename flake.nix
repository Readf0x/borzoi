rec {
  description = "Issue hunter";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = inputs @ {self, flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      perSystem = {
        system,
        pkgs,
        lib,
        ...
      }: let
        info = {
          projectName = "borzoi";
        };
      in
        ({
          projectName,
        }: rec {
          devShells = {
            default = pkgs.mkShell {
              packages = with pkgs; [ odin ];
            };
            debug = pkgs.mkShell {
              packages = with pkgs; [ odin packages.default ];
            };
          };
          packages = {
            ${projectName} = pkgs.stdenv.mkDerivation (final: {
              pname = projectName;
              version = "0.1.0";

              src = ./.;

              nativeBuildInputs = with pkgs; [ odin ];
              buildInputs = [];

              VERSIONSTR = "borzoi version ${final.version}, built from commit ${self.sourceInfo.shortRev or self.sourceInfo.dirtyShortRev} with nix";
              DESTDIR = placeholder "out";
              PREFIX = "";

              meta = {
                inherit description;
                homepage = "https://github.com/readf0x/borzoi";
                license = lib.licenses.gpl3Only;
              };
            });
            default = packages.${projectName};
          };
        })
        info;
    };
}
