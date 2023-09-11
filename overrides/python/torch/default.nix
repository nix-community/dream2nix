{
  config,
  lib,
  ...
}: {
  env.autoPatchelfIgnoreMissingDeps = ["libcuda.so.1"];
  mkDerivation.dontStrip = true;
}
