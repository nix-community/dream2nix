{
  config,
  lib,
  ...
}: {
  mkDerivation.postFixup =
    # prevents conflicts in nixpkgs buildEnv for python
    lib.mkIf (lib.hasSuffix ".whl" config.mkDerivation.src)
    "rm $out/lib/*/site-packages/nvidia/__pycache__/__init__.*";
}
