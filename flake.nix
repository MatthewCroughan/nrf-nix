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
          # It's not entirely clear based on the documentation which of all of these
          # dependencies are actually necessary to build Zephyr, the list may increase
          # depending on the ongoing changes upstream
          zephyrPython = pkgs.python3.withPackages (p: with p; [
            docutils
            wheel
            breathe
            sphinx
            sphinx_rtd_theme
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
            pyyaml
            cbor2
            west
            ecdsa
            anytree
          ]);
        };
        devShells.default =
          let
            westWorkspace = pkgs.fetchWestWorkspace {
              url = "https://github.com/nrfconnect/sdk-nrf";
              rev = "v2.1.0";
              sha256 = "sha256-LoL0SzPiKfXxWnZdbx+3m0bzyPeHovWNlmkFQsmiR7g=";
            };
          in pkgs.mkShell {
            shellHook = ''
#            export GNUARMEMB_TOOLCHAIN_PATH=$#{pkgs.gcc-arm-embedded-11}

            echo "Creating mutable west workspace in /tmp/nrf-nix and forcing VSCode to use it"
            rm -rf /tmp/nrf-nix
            cp -r --no-preserve=mode ${westWorkspace} /tmp/nrf-nix

            export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
            export ZEPHYR_SDK_INSTALL_DIR=${pkgs.zephyr-sdk};
            export ZEPHYR_BASE="/tmp/nrf-nix/zephyr"
            export PATH=${pkgs.zephyr-sdk}/arm-zephyr-eabi/bin:$PATH
            export PYTHONPATH=${pkgs.zephyrPython}/lib/python3.10/site-packages:$PYTHONPATH
          '';
          buildInputs = with pkgs;
          let
            otherExtensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
              {
                name = "nrf-connect-extension-pack";
                publisher = "nordic-semiconductor";
                version = "2023.6.6";
                sha256 = "sha256-pq+O2Nctd4Op8pW6lLXI1J1QBYtUeo0thczfnSe+8CA=";
              }
              {
                name = "nrf-terminal";
                publisher = "nordic-semiconductor";
                version = "2023.6.78";
                sha256 = "sha256-vJtlarLrlzcGmnXr+mqEeL3L7dKskuFXE9/mgS/1dN0=";
              }
              {
                name = "nrf-kconfig";
                publisher = "nordic-semiconductor";
                version = "2023.6.51";
                sha256 = "sha256-Bx68ANr/efOVTAqf1JXi8ZMnzHCKwf+pHE+YD710LUE=";
              }
              {
                name = "nrf-devicetree";
                publisher = "nordic-semiconductor";
                version = "2023.6.108";
                sha256 = "sha256-V+jloKRu9komxzRdEIjTIcduwpD9fimXwTAgrZWzeiM=";
              }
              {
                name = "nrf-connect";
                publisher = "nordic-semiconductor";
                version = "2022.7.111";
                sha256 = "sha256-td97z4H5/G8Xgy66kY0N5z/eqWf15S0BL0FtvquYgUE=";
              }
              {
                name = "gnu-mapfiles";
                publisher = "trond-snekvik";
                version = "1.1.0";
                sha256 = "sha256-JHdOqCjHbxHlth2PQ6r7SfNqedKwu6Fsot/mhPPFJhA=";
              }
          ];
            vscodeFhs = (pkgs.vscode-fhsWithPackages (p: with p; [
              nrf-command-line-tools
              segger-jlink
              dtc
              gn
              gperf
              ninja
              cmake
              zephyrPython
            ]));
            myVscode = vscode-with-extensions.override {
              vscode = vscodeFhs;
              # https://marketplace.visualstudio.com/items?itemName=nordic-semiconductor.nrf-connect-extension-pack
              vscodeExtensions = with pkgs.vscode-extensions; [
                ms-vscode.cpptools
                twxs.cmake
              ] ++ otherExtensions;
            };
          in [
            myVscode
            nrfconnect
              nrf-command-line-tools
              dtc
              gn
              gperf
              ninja
              cmake
              zephyrPython
          ];
        };
      };
      flake = {
      };
    };
}


