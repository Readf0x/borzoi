rec {
  description = "Description for the project";
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      perSystem = {
        system,
        pkgs,
        ...
      }: let
        info = {
          projectName = "issue-tracker";
        };
      in
        ({
          projectName,
        }: rec {
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              odin
            ];
          };
          packages = {
            ${projectName} = pkgs.stdenv.mkDerivation rec {
              name = projectName;
              pname = name;
              version = "0.1";
              src = ./.;
              nativeBuildInputs = with pkgs; [ odin ];
              buildInputs = [];
              buildPhase = ''
                odin build . -out:${projectName}
              '';
              meta = {
                inherit description;
                # homepage = "";
                # license = lib.licenses.;
                # maintainers = with lib.maintainers; [  ];
              };
            };
            default = packages.${projectName};
          };
        })
        info;
    };
}
