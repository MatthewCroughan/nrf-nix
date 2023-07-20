{
  description = "Unfucking the Zephyr/Nrf Experience";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zephyr-sdk = {
      url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.15.2/zephyr-sdk-0.15.2_linux-x86_64.tar.gz";
      flake = false;
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        flake-parts.flakeModules.easyOverlay
      ];
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs { inherit system; overlays = [ inputs.self.overlays.default ]; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
        overlayAttrs = config.packages // config.legacyPackages;
        legacyPackages = {
          fetchWestWorkspace = pkgs.callPackage ./functions/fetchWestWorkspace { };
          mkZephyrProject = pkgs.callPackage ./functions/mkZephyrProject { };
        };
        packages = {
          zephyr-sdk = pkgs.stdenv.mkDerivation {
            name = "zephyr-sdk-patched";
            nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
            buildInputs = with pkgs; [ pkgs.stdenv.cc.cc.lib python38 ];
            installPhase = "ls -lah";
            src = inputs.zephyr-sdk;
            buildPhase = ''
              cp -r $src $out
            '';
          };
        };
      };
      flake = {
      };
    };
}


