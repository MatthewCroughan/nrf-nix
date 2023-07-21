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
, lib
}:

{ name
, src
, board
, app
, westWorkspace
, filesToInstall ? [ "merged.hex" "app_update.bin" ]
, ...
}@args:
stdenv.mkDerivation (args // {
  inherit name;
  src = null;
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
  phases = [
    "unpackPhase"
    "buildPhase"
    "installPhase"
    "patchPhase"
    "fixupPhase"
  ];
  unpackPhase = ''
    cp -r --no-preserve=mode ${westWorkspace} ./source
    cp -r --no-preserve=mode ${src} ./source/project
    cd source
    runHook postUnpack
  '';
  buildPhase = ''
    runHook preBuild
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}

    cd project

    west -vvv build -b ${board} ${app}
    runHook postBuild
  '';
  # It may be a good idea to take an argument like `filesToInstall = []` which
  # would select files from the build result to move to $out
  installPhase = ''
    runHook preInstall
    mkdir $out
    mv -v build/zephyr/{${lib.concatStringsSep "," filesToInstall}} $out
    runHook postInstall
  '';
})
