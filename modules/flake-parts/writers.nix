{
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: let
    writers = pkgs.callPackage ../../pkgs/writers {};
  in {
    options.writers = {
      writePureShellScript = lib.mkOption {
        type = lib.types.functionTo lib.types.anything;
      };
      writePureShellScriptBin = lib.mkOption {
        type = lib.types.functionTo lib.types.anything;
      };
    };

    config.writers = {
      inherit
        (writers)
        writePureShellScript
        writePureShellScriptBin
        ;
    };
  };
}
