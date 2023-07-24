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
, filesToInstall ? [ "merged.hex" "app_update.bin" "zephyr.hex" ] # https://developer.nordicsemi.com/nRF_Connect_SDK/doc/2.1.0/nrf/app_build_system.html#output-build-files
, cmakeFlags ? []
, ...
}@args:
stdenv.mkDerivation (args // {
  inherit name;
  inherit cmakeFlags;
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

    west ${verbosityFlags} build -b ${board} ${app} ${lib.optionalString (cmakeFlags != []) "-- ${toString cmakeFlags}"}
    runHook postBuild
  '';
  installPhase = ''
    function installFailure {
      echo
      echo "------"
      echo "set the filesToInstall argument of mkZephyrProject"
      echo "to a list of files to extract from the build directory"
      echo "above are some of the files produced by this build"
      echo
      echo "https://developer.nordicsemi.com/nRF_Connect_SDK/doc/2.1.0/nrf/app_build_system.html#output-build-files"
      echo
      echo 'an example might be filesToInstall = [ "merged.hex" "app_update.bin" ]'
      echo
      echo "------"
      echo
      exit 1
    }
    runHook preInstall
    mkdir $out

    echo ------
    ls -lah build/zephyr
    echo ------

    ( cd build/zephyr && cp -r -v ${lib.concatStringsSep " " filesToInstall} $out ) || installFailure
    runHook postInstall
  '';
})
