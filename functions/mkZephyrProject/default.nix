{ stdenv
, dtc
, gn
, gperf
, ninja
, cmake
, zephyr-sdk
, python3
}:

{ name
, src
, board
, app
, westWorkspace
, ...
}@args:
let
  zephyrPython = python3.withPackages (p: with p; [
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
stdenv.mkDerivation (args // {
  inherit src name;
  nativeBuildInputs = [
    zephyrPython
    gperf
    gn
    dtc
    ninja
    cmake
  ];
  configurePhase = "true";
  buildPhase = ''
    export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
    export ZEPHYR_SDK_INSTALL_DIR=${zephyr-sdk}
    export ZEPHYR_BASE=${westWorkspace}

    west build -b ${board} ${app} --build-dir $out
  '';
  installPhase = ''
    mkdir $out
    mv -v build/zephyr/{merged.hex,app_update.bin} $out
  '';
})
