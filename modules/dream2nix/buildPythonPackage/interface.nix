{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  boolOpt = l.mkOption {
    type = t.bool;
    default = false;
  };
in {
  options.deps.python = l.mkOption {
    type = t.package;
    description = "The python interpreter package to use";
  };

  options.buildPythonPackage = {
    disabled =
      boolOpt
      // {
        description = ''
          used to disable derivation, useful for specific python versions
        '';
      };

    catchConflicts =
      boolOpt
      // {
        description = ''
          Raise an error if two packages are installed with the same name
          TODO: For cross we probably need a different PYTHONPATH, or not
          add the runtime deps until after buildPhase.
        '';
        default =
          config.deps.python.stdenv.hostPlatform
          == config.deps.python.stdenv.buildPlatform;
        defaultText = ''
          true if the host and build platforms are the same, false otherwise.
        '';
      };

    dontWrapPythonPrograms =
      boolOpt
      // {
        description = ''
          Skip wrapping of python programs altogether
        '';
      };

    makeWrapperArgs = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Additional arguments to pass to the makeWrapper function, which wraps generated binaries.
      '';
    };

    dontUsePipInstall =
      boolOpt
      // {
        description = ''
          Don't use Pip to install a wheel
          Note this is actually a variable for the pipInstallPhase in pip's setupHook.
          It's included here to prevent an infinite recursion.
        '';
      };

    permitUserSite =
      boolOpt
      // {
        description = ''
          Skip setting the PYTHONNOUSERSITE environment variable in wrapped programs
        '';
      };

    removeBinBytecode =
      boolOpt
      // {
        default = true;
        description = ''
          Remove bytecode from bin folder.
          When a Python script has the extension `.py`, bytecode is generated
          Typically, executables in bin have no extension, so no bytecode is generated.
          However, some packages do provide executables with extensions, and thus bytecode is generated.
        '';
      };

    pyproject = l.mkOption {
      type = t.nullOr t.bool;
      default = null;
      description = ''
        Whether the pyproject format should be used. When set to `true`,
        `pypaBuildHook` will be used, and you can add the required build dependencies
        from `build-system.requires` to `build-system`.

        Note that the pyproject format falls back to using `setuptools`, so
        you can use `pyproject = true` even if the package only has a `setup.py`.
        When set to `false`, you can use the existing hooks or provide your own
        logic to build the package. This can be useful for packages that don't
        support the pyproject format.

        When unset, the legacy `setuptools` hooks are used for backwards compatibility.
      '';
    };

    build-system = l.mkOption {
      type = t.listOf (t.oneOf [t.str t.path t.package]);
      default = [];
      description = ''
        Build-time only Python dependencies. Items listed in `build-system.requires`/`setup_requires`.
      '';
    };

    dependencies = l.mkOption {
      type = t.listOf (t.oneOf [t.str t.path t.package]);
      default = [];
      description = ''
        List of runtime python dependencies. Aside from propagating dependencies,
        `buildPythonPackage` also injects code into and wraps executables with the
        paths included in this list. Items listed in `install_requires` go here.
      '';
    };

    optional-dependencies = l.mkOption {
      type = t.attrsOf (t.oneOf [t.str t.path t.package]);
      default = {};
      description = ''
        Optional feature flagged dependencies. Items listed in `extras_requires` go here.
      '';
    };

    format = l.mkOption {
      type = t.nullOr t.str;
      default =
        if config.buildPythonPackage.pyproject == null
        then "setuptools"
        else null;
      description = ''
        Several package formats are supported:
          `null`: Disable this legacy option and use the new `pyproject` option instead.
          "setuptools" : Install a common setuptools/distutils based package. This builds a wheel.
          "wheel" : Install from a pre-compiled wheel.
          "flit" : Install a flit package. This builds a wheel.
          "pyproject": Install a package using a ``pyproject.toml`` file (PEP517). This builds a wheel.
          "egg": Install a package from an egg.
          "other" : Provide your own buildPhase and installPhase.
      '';
    };

    disabledTestPaths = l.mkOption {
      type = t.listOf t.anything;
      default = [];
      description = ''
        Test paths to ignore in checkPhase
      '';
    };

    # previously only set via env
    disabledTests = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Disable running specific unit tests
      '';
    };
    pytestFlagsArray = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Extra flags passed to pytest
      '';
    };
    pipInstallFlags = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Extra flags passed to `pip install`
      '';
    };
    pythonImportsCheck = l.mkOption {
      type = t.listOf t.str;
      default = [];
      description = ''
        Check whether importing the listed modules works
      '';
    };
  };
}
