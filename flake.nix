{
  nixConfig.bash-prompt = "\\[\\033[1m\\][nrf-nix-devshell]\\[\\033\[m\\]\\040\\w$\\040";
  inputs = {
    nixpkgs2003.url = "github:nixos/nixpkgs/nixos-20.03";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs2111.url = "github:nixos/nixpkgs/nixos-21.11";
    stargate-nixpkgs.url = "github:stargate01/nixpkgs/nrf-command-line-tools";
  };
  outputs = { self, nixpkgs2111, nixpkgs2003, nixpkgs, stargate-nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
      pkgs2111 = import nixpkgs2111 { system = "x86_64-linux"; config.allowUnfree = true; };
      pkgs2003 = import nixpkgs2003 { system = "x86_64-linux"; config.allowUnfree = true; };
      stargate-pkgs = import stargate-nixpkgs { system = "x86_64-linux"; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
    in
    {
      devShells.x86_64-linux.forPaul =
        let
          nrfConnectExtension = pkgs.vscode-utils.extensionFromVscodeMarketplace {
            name = "nrf-connect";
            publisher = "nordic-semiconductor";
            version = "2022.6.142";
            sha256 = "sha256-so2Ir0ZbZeJBo6J285fHC6jsGBzj808bC1i8uP10QPQ=";
          };
          myVscode = pkgs.vscode-with-extensions.override {
            vscode = pkgs.vscodium-fhs;
            vscodeExtensions = [ nrfConnectExtension ];
          };
        in pkgs.mkShell
        {
          buildInputs = [ myVscode ];
        };
      devShell.x86_64-linux =
        let
          zephyrPython = pkgs.python3.withPackages (p: with p; [
            west
            docutils
            wheel
            breathe
            sphinx
            sphinx_rtd_theme
            pyyaml
            ply
            pyelftools
            pyserial
            pykwalify
            colorama
            pillow
            intelhex
            pytest
            gcovr
            tkinter
            future
            cryptography
            setuptools
            pyparsing
            click
            kconfiglib
            pylink-square
          ]);
        in
        pkgs.mkShell {
          buildInputs = [
            # Undocumented Deps
            pkgs.file

            # Suggested
            pkgs.cmake
            pkgs.gn

            # Minimal
            pkgs2111.nrfutil
            stargate-pkgs.segger-jlink
            stargate-pkgs.nrf-command-line-tools
          ];
        };
    };
}
