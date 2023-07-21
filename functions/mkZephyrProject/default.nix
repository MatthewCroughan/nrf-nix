{ stdenv
, dtc
, gn
, gperf
, ninja
, cmake

# From overlay
, zephyr-sdk
, zephyrPython

, python3
, nrf-command-line-tools
, git
}:

{ name
, src
, board
, app
, westWorkspace
, ...
}@args:
stdenv.mkDerivation (args // {
  inherit src name;
  nativeBuildInputs = [
    zephyrPython
    git
    # Not clear if gperf/gn may be needed at some stage
    # gperf
    # gn
    dtc
    ninja
    cmake
  ];
  dontConfigure = "true";
  buildPhase = ''
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}

    cp -r --no-preserve=mode ${westWorkspace} ./tmp
    cp -r --no-preserve=mode ${src} ./tmp/project
    cd tmp

    west -vvv build -b ${board} project/${app}
  '';
  # It may be a good idea to take an argument like `filesToInstall = []` which
  # would select files from the build result to move to $out
  installPhase = ''
    mkdir $out
    mv -v build/zephyr/{merged.hex,app_update.bin} $out
  '';
})
