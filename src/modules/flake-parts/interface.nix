{
  self,
  lib,
  flake-parts-lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    dream2nix = {
      lib = l.mkOption {
        type = t.raw;
        readOnly = true;
        description = ''
          The system-less dream2nix library.
          This should be the the `lib` attribute of the dream2nix flake.
        '';
      };
      config = l.mkOption {
        type = t.submoduleWith {
          modules = [../config];
        };
        default = {
          projectRoot = self;
        };
        defaultText = lib.literalExpression ''
          {
            projectRoot = self;
          }
        '';
        description = ''
          The dream2nix config.
        '';
      };
    };
    perSystem =
      flake-parts-lib.mkPerSystemOption
      ({config, ...}: {
        options = {
          dream2nix = {
            instance = l.mkOption {
              type = t.raw;
              readOnly = true;
              description = ''
                The dream2nix instance.
              '';
            };
            inputs = l.mkOption {
              type = t.attrsOf (t.submoduleWith {
                modules = [./inputs.nix];
                specialArgs = {
                  framework = config.dream2nix.instance;
                };
              });
              default = {};
              description = ''
                A list of inputs to generate outputs from.
                Each one takes the same arguments `makeOutputs` takes.
              '';
            };
            outputs = l.mkOption {
              type = t.lazyAttrsOf (t.lazyAttrsOf t.raw);
              readOnly = true;
              description = ''
                The raw outputs that were generated for each input.
              '';
            };
          };
        };
      });
  };
}
