{config, lib, drv-parts, dependencySets, ...}: let

  l = lib // builtins;
  t = l.types;

in {

  options.mach-nix = {

    pythonSources = l.mkOption {
      type = t.package;
      description = ''
        A package that contains fetched python sources.
        Each single python source must be located in a subdirectory named after the package name.
      '';
    };

    substitutions = l.mkOption {
      type = t.lazyAttrsOf t.package;
      description = ''
        Substitute individual python packages from nixpkgs.
      '';
      default = {};
    };

    manualSetupDeps = l.mkOption {
      type = t.lazyAttrsOf (t.listOf t.str);
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

    drvs = l.mkOption {
      type = t.attrsOf (t.submoduleWith {
        modules = [drv-parts.modules.drv-parts.core];
        specialArgs = {inherit dependencySets;};
      });
      description = "drv-parts modules that define python dependencies";
    };

    # LIB

    lib.extractPythonAttrs = l.mkOption {
      type = t.functionTo t.attrs;
      description = ''
        Helper function to extract python attrs from nixpkgs to be re-used as overrides.
      '';
      readOnly = true;
    };

    # INTERNAL

    dists = l.mkOption {
      type = t.lazyAttrsOf t.str;
      description = ''
        Attrs which depend on IFD and therefore should be cached
      '';
      internal = true;
      readOnly = true;
    };
  };
}
