It is possible to use symlinks to improve the performnace of the unpackPhase,
but the consequence is that the build dir is not mutable, leading to problems
with preprocessing and patching that you might want to apply before the build in
the mkZephyrProject function call

```nix
...
  # Create the combined west workspace by overlaying the project and westWorkspace
  # via symlinks instead of cp, for performance
  unpackPhase = ''
    shopt -s dotglob extglob
    mkdir -p ./source/{project,.west}
    ln -s ${src}/!(*.west) ./source/project
    ln -s ${westWorkspace}/!(*.west) ./source

    # West wants only the .west/config to be mutable
    cp --no-preserve=mode ${westWorkspace}/.west/config ./source/.west/config

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

    export HOME=$TMP
    git config --global --add safe.directory '*'

    # CMake tries to use /nix/store/foo/.cache unless $HOME/.cache exists, due to symlinking above
    mkdir -p $HOME/.cache

    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}

    cd project

    west ${verbosityFlags} build -b ${board} ${app}
    runHook postBuild
  '';
  ...
```
