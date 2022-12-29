{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
#    sdk =
#      let
#        ZEPHYR_TOOLCHAIN_VERSION = "0.15.2";
#      in
#      builtins.fetchTarball { url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_linux-x86_64.tar.gz"; sha256 = "0pagbglg7jgz05hs5nbnqahcr43l338jbb51ip8sraa7kpi7gcrq"; };
    zephyrPython = pkgs.python3.withPackages (p: with p; [
#      west
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
    zephyrFolder = pkgs.runCommand "zephyr-folder"
      {
        nativeBuildInputs = [ pkgs.cacert pkgs.git pkgs.python3Packages.west ];
        outputHash = "sha256-A18/cKzkKCjMeDkQDa4C9J7xohAALPFvCCD/2oLYO4k=";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      }
      ''
        mkdir stuff && cd stuff
        west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.1-branch
        west update --narrow -o=--depth=1
        for i in $(find ./ -name '*.git')
        do
          rm -rf $i
        done
        mkdir $out
        shopt -s dotglob
        mv * $out
      '';
    arm-toolchain = pkgs.buildEnv {
      name = "arm-toolchain";
      paths = with pkgs; [
        pkgsCross.arm-embedded.buildPackages.binutils
        gcc-arm-embedded
        stdenv.cc.cc.lib
        ninja

        which
        cmake
        dtc
        gperf
        openocd
        dfu-util
        bossa
        (nrfutil.overrideAttrs (_: rec {
          version = "6.1.7";
          src = fetchFromGitHub {
            owner = "NordicSemiconductor";
            repo = "pc-nrfutil";
            rev = "v${version}";
            sha256 = "sha256-WiXqeQObhXszDcLxJN8ABd2ZkxsOUvtZQSVP8cYlT2M=";
          };
        }))
        nrf-command-line-tools
        # jlink
        segger-jlink
        srecord # for srec_cat
      ];
    };
  in
  {
    packages.x86_64-linux.exampleProject =
      pkgs.stdenv.mkDerivation {
        cmakeFlags = with pkgs; [
          "-DCMAKE_C_COMPILER=${clang}/bin/clang"
          "-DCMAKE_CXX_COMPILER=${clang}/bin/clang++"
        ];
        postUnpack = "
        cp -r --no-preserve=mode ${zephyrFolder}/zephyr ./zephyr
        echo $PWD
        ";
        Zephyr_DIR = "/build/zephyr";
        name = "foo";
        src = ./.;
        nativeBuildInputs = with pkgs; [
          cmake ninja
          pkgsCross.arm-embedded.buildPackages.binutils
          gcc-arm-embedded
          stdenv.cc.cc.lib
        ];
        buildInputs = with pkgs; [
          # Undocumented Deps
          file
          git

          # Suggested
          cmake
          gn

          # Minimal
          nrfutil
          segger-jlink
          nrf-command-line-tools

          # Unsure
          zephyrPython
        ];
        BOARD = "nrf9160dk_nrf9160_ns";
        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
#        Zephyr-sdk_DIR = sdk;
      };
  };
}
