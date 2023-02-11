{config, lib, drv-parts, ...}: let

  l = lib // builtins;
  t = l.types;

in {

  options = {

    pythonSources = l.mkOption {
      type = t.package;
      description = ''
        A package that contains fetched python sources.
        Each single python source must be located ina subdirectory named after the package name.
      '';
    };

    substitutions = l.mkOption {
      type = t.attrsOf t.package;
      description = ''
        Substitute individual python packages from nixpkgs.
      '';
      default = {};
    };

    manualSetupDeps = l.mkOption {
      type = t.attrsOf (t.listOf t.str);
      description = ''
        Replace the default setup dependencies from nixpkgs for sdist based builds
      '';
      default = {};
      example = {
        vobject = [
          "python-dateutil"
          "six"
        ];
        libsass = [
          "six"
        ];
      };
    };

    overrides = l.mkOption {
      type = t.attrsOf (t.functionTo t.attrs);
      description = ''
        Overrides for sdist package builds
      '';
      default = {};
    };
  };
}
