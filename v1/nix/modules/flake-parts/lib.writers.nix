{
  self,
  lib,
  ...
}: {
  flake.lib.writers = pkgs: pkgs.callPackage ../../pkgs/writers {};
}
