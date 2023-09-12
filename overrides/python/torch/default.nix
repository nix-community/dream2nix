{
  config,
  lib,
  ...
}: {
  # stripping doesn't reduce the file size much, and it takes a long time
  mkDerivation.dontStrip = true;

  # this file is patched manually, so ignore it in autoPatchelf
  env.autoPatchelfIgnoreMissingDeps = ["libcuda.so.1"];
  # patch the rpath so libcuda.so.1 can be found at /run/opengl-driver/lib
  env.cudaPatchPhase = ''
    patchelf $out/${config.deps.python.sitePackages}/torch/lib/libcaffe2_nvrtc.so \
      --add-rpath /run/opengl-driver/lib
  '';
  mkDerivation.postPhases = ["cudaPatchPhase"];
}
