{
  config,
  lib,
  ...
}: {
  # stripping doesn't reduce the file size much, and it takes a long time
  mkDerivation.dontStrip = true;

  # use the autoAddDriverRunpath to add /run/opengl-driver/lib to the RPATH
  #   of all ELF files
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) autoAddDriverRunpath;
  };
  mkDerivation.nativeBuildInputs = [
    config.deps.autoAddDriverRunpath
  ];

  # this file is patched manually, so ignore it in autoPatchelf
  env.autoPatchelfIgnoreMissingDeps = ["libcuda.so.1"];
}
