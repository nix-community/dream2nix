{
  config,
  lib,
  dream2nix,
  extendModules,
  ...
}: {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.core
  ];
  # make the core module happy
  inherit (config.out) name;
  inherit (config.out) version;

  # make the top-level look like a derivation under 'out'
  public = {
    inherit extendModules;
    inherit
      (config.out)
      config
      drvPath
      name
      outPath
      outputName
      outputs
      type
      version
      ;
    out = config.out.public;
  };
}
