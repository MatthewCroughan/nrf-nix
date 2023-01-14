{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  outputs = { self, nixpkgs }:
  let
    pkgs = import nixpkgs { system = "x86_64-linux"; config = { allowUnfree = true; segger-jlink.acceptLicense = true; }; };
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
    sdk =
      let
        ZEPHYR_TOOLCHAIN_VERSION = "0.15.2";
      in
      builtins.fetchTarball { url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_linux-x86_64.tar.gz"; sha256 = "0pagbglg7jgz05hs5nbnqahcr43l338jbb51ip8sraa7kpi7gcrq"; };
   zephyrPython = pkgs.python310.withPackages (p: with p; [
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
        outputHash = "sha256-mSCCozWpYmIOjStMAlhA5ZcelZMfSdI2QgXkD19uIn0=";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      }
      ''
        mkdir stuff && cd stuff
#        west init ./.
#        west update
        west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.1-branch
        west update --narrow -o=--depth=1
        git clone https://github.com/zephyrproject-rtos/hal_nordic.git
        for i in $(find ./ -name '*.git')
        do
          rm -rf $i
        done
        mkdir $out
#        shopt -s dotglob
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
      pkgs.gcc12Stdenv.mkDerivation {
        outputHash = "";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        cmakeFlags = with pkgs; [
          "-LA"
          "-DCMAKE_C_COMPILER=${lib.getBin stdenv.cc}/bin/cc"
          "-DCMAKE_CXX_COMPILER=${lib.getBin stdenv.cc}/bin/c++"
          "-DUSER_CACHE_DIR=/build/.cache"
          "-DBUILD_VERSION=65a99697fa604e28cb26ec96ce935ad720222892"
          "-DARM_MBEDTLS_PATH=${pkgs.mbedtls}"
        ];
        preBuild = ''
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          ls -lah /build/workdir/project/build
          cat /build/workdir/project/build/zephyr_modules.txt
        '';
        preConfigure = ''
          shopt -s dotglob
          mkdir -p /build/workdir
          cp -r /build/class_a /build/workdir/project
          cp -r --no-preserve=mode ${/home/matthew/tmp/tmp.KjvftECv2w}/* /build/workdir
          cd /build/workdir/project
          export Zephyr_DIR="$PWD/.."
          export ZEPHYR_BASE="$PWD/../zephyr"
          export PATH="''${ZEPHYR_BASE}/scripts:''${PATH}"
          west list
          cp -r --no-preserve=mode ${sdkPatched} /build/workdir/zephyr-sdk
          ls -lah /build/workdir
          west build
        '';
        name = "foo";
        src = ./.;
        LC_ALL = "C.UTF-8";
        LANG = "C.UTF-8";
        nativeBuildInputs = with pkgs; [
          dtc
          cmake ninja
          git
          cacert
          python3Packages.west
#          pkgsCross.arm-embedded.buildPackages.binutils
#          gcc-arm-embedded
#          stdenv.cc.cc.lib
          zephyrPython
        ];
        buildInputs = with pkgs; [
          # Undocumented Deps
#          file
#          git

          # Suggested
#          cmake
#          gn

          # Minimal
#          nrfutil
#          segger-jlink
#          nrf-command-line-tools

          # Unsure
        ];
        BOARD = "nrf9160dk_nrf9160_ns";
        XDG_CACHE_HOME = "/build/.cache";
#        LIBGCC_FILE_NAME = pkgs.stdenv.cc.cc.lib;
        ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
#        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
#        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
        ZEPHYR_SDK_INSTALL_DIR = sdkPatched;
      };
#    packages.x86_64-linux.exampleProject =
#      pkgs.gcc12Stdenv.mkDerivation {
#        cmakeFlags = with pkgs; [
#          "-DCMAKE_C_COMPILER=${lib.getBin stdenv.cc}/bin/cc"
#          "-DCMAKE_CXX_COMPILER=${lib.getBin stdenv.cc}/bin/c++"
#          "-DUSER_CACHE_DIR=/build/.cache"
#          "-DBUILD_VERSION=65a99697fa604e28cb26ec96ce935ad720222892"
#          "-DARM_MBEDTLS_PATH=${pkgs.mbedtls}"
#          "-DZEPHYR_MODULES=${zephyrFolder}/modules;${zephyrFolder}/hal_nordic;${zephyrFolder}/bootloader;${zephyrFolder}/mbedtls;${zephyrFolder}/nrfxlib;${zephyrFolder}/test;${zephyrFolder}/tools;${zephyrFolder}/nrf"
#        ];
#        Zephyr_DIR = "${zephyrFolder}";
#        postUnpack = "ls -lah ${zephyrFolder}";
#        preBuild = "cmake -LAH | grep ZEPHYR";
#        name = "foo";
#        src = ./.;
#        LC_ALL = "C.UTF-8";
#        LANG = "C.UTF-8";
#        nativeBuildInputs = with pkgs; [
#          dtc
#          cmake ninja
#          pkgsCross.arm-embedded.buildPackages.binutils
#          gcc-arm-embedded
#          stdenv.cc.cc.lib
#          zephyrPython
#        ];
#        buildInputs = with pkgs; [
#          # Undocumented Deps
##          file
##          git
#
#          # Suggested
##          cmake
##          gn
#
#          # Minimal
##          nrfutil
##          segger-jlink
##          nrf-command-line-tools
#
#          # Unsure
#        ];
#        BOARD = "nrf9160dk_nrf9160";
#        XDG_CACHE_HOME = "/build/.cache";
#        LIBGCC_FILE_NAME = pkgs.stdenv.cc.cc.lib;
#        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
#        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
##        ZEPHYR_SDK_INSTALL_DIR = sdk;
#      };
  };
}
