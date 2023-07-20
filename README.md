# Example

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nrf-nix.url = "github:matthewcroughan/nRF-nix";
  };
  outputs = { self, nixpkgs, nrf-nix, ... }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; overlays = [ nrf-nix.overlays.default ]; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
  in
  {
    packages.x86_64-linux.default = pkgs.mkZephyrProject rec {
      name = "example-application";
      app = name;
      board = "actinius_nf9160_ns";
      westWorkspace = pkgs.fetchWestWorkspace {
        url = "https://github.com/nrfconnect/sdk-nrf";
        rev = "v2.1.0";
        sha256 = "sha256-LoL0SzPiKfXxWnZdbx+3m0bzyPeHovWNlmkFQsmiR7g=";
      };
      src = self;
    };
  };
}
```

