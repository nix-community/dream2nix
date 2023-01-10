# Integrate lang2nix tool (pure)
We use [crane](https://crane.dev) as an example here to demonstrate creating a dream2nix integration

`dream2nix/modules/rust.crane-buildPackage.nix`
```nix
{config, lib, dream2nix, system, ...}: rec {

  imports = [
    # import generic mkDerivation interface, which will add options like:
    #   - buildInputs
    #   - nativeBuildInputs
    #   - ...
    dream2nix.modules.mkDerivation-interfaces
  ];

  options = {
    buildPhaseCargoCommand = lib.mkOption {
      description = "A command to run during the derivation's build phase. Pre and post build hooks will automatically be run.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    cargoArtifacts = lib.mkOption {
      description = "A path (or derivation) which contains an existing cargo target directory, which will be reused at the start of the derivation. Useful for caching incremental cargo builds.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    cargoBuildCommand = lib.mkOption {
      description = "A cargo invocation to run during the derivation's build phase";
      type = lib.types.nullOr lib.types.str;
      default = null;
    }

    # ... more options of crane's buildPackage
  };

  config = {
    # signal that all options should be passed to the final derivation function
    argsForward = l.mapAttrs (_: _: true) options;

    # the final derivation is built by calling crane.buildPackage
    config.final.derivation =
      dream2nix.inputs.crane.lib.${system}.buildPackage
      config.final.derivation-args;
  };
}
```
