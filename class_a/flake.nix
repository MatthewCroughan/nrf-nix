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
    zephyrFolder = pkgs.runCommand "zephyr-folder" {} ''
      shopt -s dotglob
      mkdir -p $out
      cp -r --no-preserve=mode ${zephyrFolderUnpatched} ./foo
      cd ./foo
      for i in $(find ./precomputed -type f)
      do
        substituteInPlace $i \
          --replace '/build/replaceMe' '${zephyrFolderUnpatched}'
      done
      substituteInPlace ./zephyr/cmake/modules/zephyr_module.cmake \
        --replace '--cmake-out ''${CMAKE_BINARY_DIR}/zephyr_modules.txt' '--cmake-out /tmp/null' \
        --replace '--settings-out ''${ZEPHYR_SETTINGS_FILE}' '--settings-out /tmp/null' \
        --replace '--kconfig-out ''${KCONFIG_MODULES_FILE}' '--kconfig-out /tmp/null'

      mv * $out
    '';
    zephyrFolderUnpatched = pkgs.runCommand "zephyr-folder"
      {
        nativeBuildInputs = [ pkgs.cacert pkgs.git pkgs.python3Packages.west pkgs.cmake ];
        outputHash = "sha256-cpmg0zwI5j0ueHkRu2bjuwvWReXLj+o+1qyurphhE+Q=";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      }
      ''
        shopt -s dotglob

        mkdir -p $out/precomputed

        mkdir replaceMe
        cd replaceMe
        west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.1-branch
        west update --narrow -o=--depth=1
        export ZEPHYR_BASE=$PWD/zephyr
        ${pkgs.python3}/bin/python3 $ZEPHYR_BASE/scripts/zephyr_module.py \
          --zephyr-base $ZEPHYR_BASE \
          --kconfig-out $out/precomputed/Kconfig.modules \
          --cmake-out $out/precomputed/zephyr_modules.txt \
          --settings-out $out/precomputed/zephyr_settings.txt

        cat $out/precomputed/zephyr_modules.txt

        for i in $(find ./ -name '*.git')
        do
          rm -rf $i
        done
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
    fuck = zephyrFolder;
    packages.x86_64-linux.project = pkgs.stdenv.mkDerivation {
        cmakeFlags = with pkgs; [
          "-LA"
          "-DZEPHYR_MODULES=none"
          "-DARM_MBEDTLS_PATH=${zephyrFolder}/mbedtls"
#          "-DZEPHYR_MODULES_PASSTHROUGH=${self.packages.x86_64-linux.exampleProject}"
#          "-DARM_MBEDTLS_PATH=/build/workdir/mbedtls"
          "-DCMAKE_C_COMPILER=${lib.getBin stdenv.cc}/bin/cc"
          "-DCMAKE_CXX_COMPILER=${lib.getBin stdenv.cc}/bin/c++"
          "-DUSER_CACHE_DIR=/build/.cache"
          "-DBUILD_VERSION=65a99697fa604e28cb26ec96ce935ad720222892"
        ];
        name = "project";
        src = ./.;
        LC_ALL = "C.UTF-8";
        LANG = "C.UTF-8";
        ZEPHYR_DIR = zephyrFolder;
        ZEPHYR_BASE = zephyrFolder + "/zephyr";
        preConfigure = ''
          export ZEPHYR_BASE="${zephyrFolder}/zephyr"

          ls -lah ${zephyrFolder}

          mkdir -p build/Kconfig
          cp -v --no-preserve=mode ${zephyrFolder}/precomputed/zephyr_modules.txt ./build
          cp -v --no-preserve=mode ${zephyrFolder}/precomputed/zephyr_settings.txt ./build
          cp -r -v --no-preserve=mode ${zephyrFolder}/precomputed/Kconfig.modules ./build/Kconfig
        '';
        installPhase = ''
          for i in $(find . -name "*.hex")
          do
            mkdir -p $out/hex
            cp -vu $i $out/hex
          done
          for i in $(find . -name "*.bin")
          do
            mkdir -p $out/bin
            cp -vu $i $out/bin
          done
        '';
        nativeBuildInputs = with pkgs; [
          dtc
          cmake ninja
          git
          cacert
          zephyrPython
        ];
        BOARD = "nrf9160dk_nrf9160_ns";
        XDG_CACHE_HOME = "/build/.cache";
        ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
#        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
#        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
        ZEPHYR_SDK_INSTALL_DIR = sdkPatched;
    };
#    packages.x86_64-linux.newAttempt =
#      pkgs.gcc12Stdenv.mkDerivation {
#        cmakeFlags = with pkgs; [
#          "-LA"
#          "-DZEPHYR_MODULES_PASSTHROUGH=${self.packages.x86_64-linux.exampleProject}"
#          "-DARM_MBEDTLS_PATH=/build/workdir/mbedtls"
#          "-DCMAKE_C_COMPILER=${lib.getBin stdenv.cc}/bin/cc"
#          "-DCMAKE_CXX_COMPILER=${lib.getBin stdenv.cc}/bin/c++"
#          "-DUSER_CACHE_DIR=/build/.cache"
#          "-DBUILD_VERSION=65a99697fa604e28cb26ec96ce935ad720222892"
#        ];
#        preConfigure = ''
#          shopt -s dotglob
#          mkdir -p /build/workdir
#          cp -r /build/class_a /build/workdir/project
#          cp -r --no-preserve=mode ${/home/matthew/tmp/tmp.KjvftECv2w}/* /build/workdir
#          cd /build/workdir/project
#          export Zephyr_DIR="$PWD/.."
#          export ZEPHYR_BASE="$PWD/../zephyr"
#          export PATH="''${ZEPHYR_BASE}/scripts:''${PATH}"
#          cp -r --no-preserve=mode ${sdkPatched} /build/workdir/zephyr-sdk
#
#          mkdir -p /build/workdir/project/build
#          cp -r --no-preserve=mode ${self.packages.x86_64-linux.exampleProject}/* /build/workdir/project/build
#        '';
#        preBuild = ''
#        '';
#        name = "newAttempt";
#        src = ./.;
#        LC_ALL = "C.UTF-8";
#        LANG = "C.UTF-8";
#        nativeBuildInputs = with pkgs; [
#          dtc
#          cmake ninja
#          git
#          cacert
##          pkgsCross.arm-embedded.buildPackages.binutils
##          gcc-arm-embedded
##          stdenv.cc.cc.lib
#          zephyrPython
#        ];
#        BOARD = "nrf9160dk_nrf9160_ns";
#        XDG_CACHE_HOME = "/build/.cache";
##        LIBGCC_FILE_NAME = pkgs.stdenv.cc.cc.lib;
#        ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
##        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
##        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
#        ZEPHYR_SDK_INSTALL_DIR = sdkPatched;
#      };
#    packages.x86_64-linux.exampleProject =
#      pkgs.gcc12Stdenv.mkDerivation {
##        outputHash = "";
##        outputHashAlgo = "sha256";
##        outputHashMode = "recursive";
#        cmakeFlags = with pkgs; [
#          "-LA"
#          "-DCMAKE_C_COMPILER=${lib.getBin stdenv.cc}/bin/cc"
#          "-DCMAKE_CXX_COMPILER=${lib.getBin stdenv.cc}/bin/c++"
#          "-DUSER_CACHE_DIR=/build/.cache"
#          "-DBUILD_VERSION=65a99697fa604e28cb26ec96ce935ad720222892"
#        ];
#        preBuild = ''
#          cat /build/workdir/project/build/zephyr_modules.txt
#        '';
#        preConfigure = ''
#          shopt -s dotglob
#          mkdir -p /build/workdir
#          cp -r /build/class_a /build/workdir/project
#          cp -r --no-preserve=mode ${/home/matthew/tmp/tmp.KjvftECv2w}/* /build/workdir
#          cd /build/workdir/project
#          export Zephyr_DIR="$PWD/.."
#          export ZEPHYR_BASE="$PWD/../zephyr"
#          export PATH="''${ZEPHYR_BASE}/scripts:''${PATH}"
#          west list
#          cp -r --no-preserve=mode ${sdkPatched} /build/workdir/zephyr-sdk
#
#          mkdir foo
#          cd foo
#
#          ${pkgs.python3}/bin/python3 $ZEPHYR_BASE/scripts/zephyr_module.py \
#            --zephyr-base $ZEPHYR_BASE \
#            --kconfig-out ./Kconfig.modules \
#            --cmake-out ./zephyr_modules.txt \
#            --settings-out ./zephyr_settings.txt
#
#          ls -lah
#          ls -lah
#          ls -lah
#          ls -lah
#          ls -lah
#          ls -lah
#          ls -lah
#          ls -lah
#
#          cd -
#        '';
#        installPhase = ''
#          ls -lah
#          mkdir -p $out/Kconfig
#          cp /build/workdir/project/build/zephyr_modules.txt $out
#          cp /build/workdir/project/build/zephyr_settings.txt $out
#          cp /build/workdir/project/build/Kconfig/Kconfig.modules $out/Kconfig/Kconfig.modules
#        '';
#        name = "foo";
#        src = builtins.filterSource (path: type:
#          !(builtins.elem (baseNameOf path) [
#            "flake.nix"
#            "flake.lock"
#          ]))
#        ./.;
#        LC_ALL = "C.UTF-8";
#        LANG = "C.UTF-8";
#        nativeBuildInputs = with pkgs; [
#          dtc
#          cmake ninja
#          git
#          cacert
#          python3Packages.west
##          pkgsCross.arm-embedded.buildPackages.binutils
##          gcc-arm-embedded
##          stdenv.cc.cc.lib
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
#        BOARD = "nrf9160dk_nrf9160_ns";
#        XDG_CACHE_HOME = "/build/.cache";
##        LIBGCC_FILE_NAME = pkgs.stdenv.cc.cc.lib;
#        ZEPHYR_TOOLCHAIN_VARIANT = "zephyr";
##        ZEPHYR_TOOLCHAIN_VARIANT = "gnuarmemb";
##        GNUARMEMB_TOOLCHAIN_PATH = arm-toolchain;
#        ZEPHYR_SDK_INSTALL_DIR = sdkPatched;
#      };
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
