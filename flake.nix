{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
    stargate-nixpkgs.url = "github:stargate01/nixpkgs/nrf-command-line-tools";
  };
  outputs = { self, nixpkgs, stargate-nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      stargate-pkgs = stargate-nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      devShell.x86_64-linux = pkgs.mkShell {
        buildInputs = [
          pkgs.nrfutil
          (stargate-pkgs.segger-jlink.override { acceptLicense = true; })
          stargate-pkgs.nrf-command-line-tools
        ];
      };
    };
}
