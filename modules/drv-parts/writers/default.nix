{
  config,
  lib,
  ...
}: let
  writers = config.deps.callPackage ../../../pkgs/writers {};
in {
  imports = [
    ./interface.nix
  ];

  config.deps = {nixpkgs, ...}:
    lib.mapAttrs (_: lib.mkOverride 1001) {
      inherit
        (nixpkgs)
        callPackage
        bash
        coreutils
        gawk
        path
        stdenv
        writeScript
        writeScriptBin
        ;
    };

  config.writers = {
    inherit
      (writers)
      writePureShellScript
      writePureShellScriptBin
      ;
  };
}
