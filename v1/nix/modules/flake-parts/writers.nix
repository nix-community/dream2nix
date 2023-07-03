{
  perSystem = {
    self,
    config,
    lib,
    pkgs,
    ...
  }: {
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
        (self.lib.writers pkgs)
        writePureShellScript
        writePureShellScriptBin
        ;
    };
  };
}
