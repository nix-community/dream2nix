{
  config,
  lib,
  ...
}: {
  # stripping doesn't reduce the file size much, and it takes a long time
  mkDerivation.dontStrip = true;

  # use the autoAddOpenGLRunpathHook to add /run/opengl-driver/lib to the RPATH
  #   of all ELF files
  deps = {nixpkgs, ...}: {
    inherit (nixpkgs.stdenv) isLinux;
    autoAddOpenGLRunpathHook = lib.optionalAttribute nixpkgs.stdenv.isLinux nixpkgs.cudaPackages.autoAddOpenGLRunpathHook;
  };

  mkDerivation.nativeBuildInputs = lib.mkIf config.deps.isLinux [
    config.deps.autoAddOpenGLRunpathHook
  ];

  # this file is patched manually, so ignore it in autoPatchelf
  env.autoPatchelfIgnoreMissingDeps = lib.mkIf config.deps.isLinux ["libcuda.so.1"];
}
