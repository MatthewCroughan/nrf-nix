{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    nixpkgs2111.url = "github:nixos/nixpkgs/nixos-21.11";
    stargate-nixpkgs.url = "github:stargate01/nixpkgs/nrf-command-line-tools";
  };
  outputs = { self, nixpkgs2111, nixpkgs, stargate-nixpkgs }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
      pkgs2111 = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
      stargate-pkgs = import stargate-nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
    in
    {
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [
          # Suggested
          pkgs.gn
          pkgs.python310Packages.west

          # Minimal
          pkgs2111.nrfutil
          (stargate-pkgs.segger-jlink.override { acceptLicense = true; })
          stargate-pkgs.nrf-command-line-tools
        ];
      };
    };
}
