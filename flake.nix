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
        export PYTHONPATH=${zephyrPython}/lib/python3.10/site-packages
      '';
      buildInputs = with pkgs; [
        nrfconnect
        (vscode-fhsWithPackages (p: with p; [
          nrf-command-line-tools
          #(nrf-command-line-tools.overrideAttrs (_: {
          #  src = fetchurl {
          #    url = "https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x/10-21-0/nrf-command-line-tools-10.21.0_linux-amd64.tar.gz";
          #    sha256 = "sha256-yjJWB2uhB0QmysZ1/YoU6VxNJC/Mr8b8yLNqQnfLkkk=";
          #  };
          #}))
          git
          dtc
          gn
          gperf
          ninja
          cmake
          zephyrPython
        ]))
      ];
    };
  };
}
