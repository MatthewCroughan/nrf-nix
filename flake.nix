{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixGL.url = "github:guibou/nixGL";
  };
  outputs = { self, nixpkgs, nixGL, ... }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
    sdk =
      let
        ZEPHYR_TOOLCHAIN_VERSION = "0.15.2";
      in
      builtins.fetchTarball { url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_linux-x86_64.tar.gz"; sha256 = "0pagbglg7jgz05hs5nbnqahcr43l338jbb51ip8sraa7kpi7gcrq"; };
    sdkPatched = pkgs.stdenv.mkDerivation {
      name = "sdkPatched";
      nativeBuildInputs = with pkgs; [ autoPatchelfHook ];
      buildInputs = with pkgs; [ pkgs.stdenv.cc.cc.lib python38 ];
      installPhase = "ls -lah";
      src = sdk;
      buildPhase = ''
        cp -r ${sdk} $out
      '';
    };
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
    ]);
  in
  {
    #TODO: Clone ZEPHYR_BASE via a fixed-output-derivation and provide it as a flake input
    #TODO: Make a wrapper function like mkZephyrProject that builds generically, taking a few arguments
    packages.x86_64-linux.example-application = let
      west-workspace = pkgs.runCommand "west-workspace"
        {
          nativeBuildInputs = [ pkgs.cacert pkgs.git pkgs.python3Packages.west ];
          outputHash = "sha256-cTCBTd/ZPPQDrDI1Re8RKreUBTAHrF2J5MwGUxhsz1E=";
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
        }
        ''
          export SOURCE_DATE_EPOCH="315532800"
          mkdir -p $out
          shopt -s dotglob
          west init -m https://github.com/zephyrproject-rtos/example-application --mr main $out
          cd $out
          west update --narrow -o=--depth=1
          for i in $(find $out -name '.git')
          do
            rm -rf $i
            echo removing $i for purity!
            echo -e "$(basename $(dirname "$i"))" >> fakeTheseRepos
          done
          sort -o fakeTheseRepos fakeTheseRepos
        '';

    in pkgs.stdenv.mkDerivation {
      name = "example-application";
      src = west-workspace;
      #src = pkgs.fetchFromGitHub {
      #  owner = "zephyrproject-rtos";
      #  repo = "example-application";
      #  rev = "2c85d9224fca21fe6e370895c089a6642a9505ea";
      #  sha256 = "";
      #};
      nativeBuildInputs = with pkgs; [
        git
        zephyrPython
          nrf-command-line-tools
          dtc
          gn
          gperf
          ninja
          cmake
      ];
      configurePhase = ''
        export HOME=$TMP
        # Git is not atomic by default due to auto-gc
        # https://stackoverflow.com/questions/28092485/how-to-prevent-garbage-collection-in-git
        git config --global gc.autodetach false

        # The west commands needs to find .git
        # Remote all .git files and replace with BS
        # Each of these is done in parallel with & and wait
        while read -r i
        do
          (
            echo creating git repo in "$i"
            git -C "$i" init
            git -C "$i" config user.email 'foo@example.com'
            git -C "$i" config user.name 'Foo Bar'
            git -C "$i" add -A
            git -C "$i" commit -m 'Fake commit'
            git -C "$i" checkout -b manifest-rev
            git -C "$i" checkout --detach manifest-rev
          ) &
        done < fakeTheseRepos
        wait
      '';
      buildPhase = ''
        export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
        export ZEPHYR_SDK_INSTALL_DIR=${sdkPatched}

        # cd into build directory, otherwise it fucks up
        # https://github.com/zephyrproject-rtos/example-application/pull/40
        cd example-application/app

        west build -b custom_plank
      '';
      installPhase = ''
        ls -lah
      '';
    };
    apps.x86_64-linux.sdkGL = {
      type = "app";
      program = builtins.toPath (pkgs.writeShellScript "sdkGL" ''
        export NIX_CONFIG="experimental-features = nix-command flakes"
        export PATH=$PATH:${pkgs.nixUnstable}/bin
        nix run --impure  ${nixGL}#nixGLDefault -- nix develop ${self}#devShell.x86_64-linux --command "code"
      '');
    };
    devShell.x86_64-linux = pkgs.mkShell {
      shellHook = ''
#        ln -s ${sdkPatched} ./fuckSdk
#        export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded-11}
        export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
        export ZEPHYR_SDK_INSTALL_DIR=${sdkPatched};
        export PATH=${sdkPatched}/arm-zephyr-eabi/bin:$PATH
        export PYTHONPATH=${zephyrPython}/lib/python3.10/site-packages:$PYTHONPATH
      '';
      buildInputs = with pkgs; 
      let
        nordic-pack = pkgs.vscode-utils.extensionsFromVscodeMarketplace [{
          name = "nrf-connect-extension-pack";
          publisher = "nordic-semiconductor";
          version = "2023.6.6";
          sha256 = "sha256-pq+O2Nctd4Op8pW6lLXI1J1QBYtUeo0thczfnSe+8CA=";
        }];
        vscodeFhs = (vscode-fhsWithPackages (p: with p; [
          nrf-command-line-tools
          git
          dtc
          gn
          gperf
          ninja
          cmake
          zephyrPython
        ]));
        myVscode = vscode-with-extensions.override {
          vscode = vscodeFhs;
          vscodeExtensions = nordic-pack;
        };
      in [
        myVscode
        nrfconnect
          nrf-command-line-tools
          git
          dtc
          gn
          gperf
          ninja
          cmake
          zephyrPython
      ];
    };
  };
}
