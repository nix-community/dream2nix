# Integrate lang2nix tool (impure/code-gen)

We use [gomod2nix](https://github.com/nix-community/gomod2nix) as an example here to demonstrate creating a dream2nix integration.

Gomod2nix is a nix code generator that requires network access, a great example for an impure dream2nix integration.

`dream2nix/modules/go.gomod2nix.nix`
```nix
{config, lib, dream2nix, system, ...}: rec {

  imports = [

    # import generic mkDerivation interface, which will add options like:
    #   - buildInputs
    #   - nativeBuildInputs
    #   - ...
    dream2nix.modules.mkDerivation-interfaces

    # Generic interface for impure lang2nix tools (code generators)
    #   This provides options like `generateBin` (see below)
    dream2nix.modules.integrations.impure
  ];

  options = {
    modules = lib.mkOption {
      description = "The path to the gomod2nix.toml";
      type = lib.types.str;
      default = "${config.dream2nix.artifactsLocation}/gomod2nix.toml" ;
    };

  };

  config = {
    # Generated code will end up in:
    #   {repo}/dream2nix/artifacts/{engineName}/{package_identifier}
    dream2nix.engineName = "gomod2nix";

    # An executable that generates nix code for the given `src`
    dream2nix.generateBin = dream2nix.utils.writePureShellScript "gomod2nix-generate.sh"
      [
        # add gomod2nix tool to PATH
        dream2nix.inputs.gomod2nix.packages.${system}.gomod2nix
      ]
      ''
        targetDir=$1
        gomod2nix --dir "${config.src}" --outdir "$targetDir"
      '';

    # signal that all options should be passed to the final derivation function
    argsForward = l.mapAttrs (_: _: true) options;

    # the final derivation is built by calling gomod2nix.buildGoApplication
    config.final.derivation =
      dream2nix.inputs.gomod2nix.lib.${system}.buildGoApplication
      config.final.derivation-args;
  };
}
```
