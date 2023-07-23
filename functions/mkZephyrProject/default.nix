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
, westVerbosity ? 0
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

  buildPhase = let
    generateVerbosityFlags = v:
  if v > 0 then
    "-" + (lib.concatStrings (lib.replicate v "v"))
  else
    "";
    verbosityFlags = generateVerbosityFlags westVerbosity;
  in ''
    runHook preBuild
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}

    cd project

    west ${verbosityFlags} build -b ${board} ${app}
    runHook postBuild
  '';
  installPhase = ''
    function installFailure {
      echo
      echo "------"
      echo "set the filesToInstall argument of mkZephyrProject to a list of files to extract from the build directory"
      echo "above are some of the files produced by this build"
      echo 'an example might be filesToInstall = [ "merged.hex" "app_update.bin" ]'
      echo "------"
      echo
      exit 1
    }
    runHook preInstall
    mkdir $out

    echo ----
    ls -lah build/zephyr
    echo ----

    ( cd build/zephyr && cp -r -v ${lib.concatStringsSep " " filesToInstall} $out ) || installFailure
    runHook postInstall
  '';
})
