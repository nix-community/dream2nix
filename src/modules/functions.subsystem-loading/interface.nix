{config, ...}: let
  lib = config.lib;
  t = lib.types;
in {
  options.functions.subsystem-loading = {
    collect = lib.mkOption {
      type = t.functionTo t.anything;
      description = ''
        Discover modules in /src/subsystems/{subsystem}/{module-type}/{module-name}
      '';
    };
    import_ = lib.mkOption {
      type = t.functionTo t.anything;
      description = ''
        Imports discovered module files.
        Adds name and subsystem attributes to each module derived from the path.
      '';
    };
    instantiate = lib.mkOption {
      type = t.functionTo t.anything;
      description = ''
        To keep module implementations simpler, additional generic logic is added
        by a loader.
        The loader is subsytem specific and needs to be passed as an argument.
      '';
    };
    structureBySubsystem = lib.mkOption {
      type = t.functionTo t.anything;
      description = ''
        re-structures the instantiated instances into a deeper attrset like:
        {subsytem}.{module-name} = ...
      '';
    };
  };
}
