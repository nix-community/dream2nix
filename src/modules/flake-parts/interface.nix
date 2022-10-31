{
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
        default = {};
        description = ''
          The dream2nix config. This will be applied to all defined `sources`.
          You can override this per `source` by specifying `config` for that source:
          ```nix
            sources."name" = {
              config.projectSource = ./source;
            };
          ```
        '';
      };
      inputs = l.mkOption {
        type = t.attrsOf t.attrs;
        default = {};
        description = ''
          A list of inputs to generate outputs from.
          Each one takes the same arguments `makeFlakeOutputs` takes.
        '';
      };
      outputs = l.mkOption {
        type = t.attrsOf t.raw;
        readOnly = true;
        description = ''
          The raw outputs that were generated.
        '';
      };
    };
    perSystem =
      flake-parts-lib.mkPerSystemOption
      ({...}: {
        options = {
          dream2nix = {
            outputs = l.mkOption {
              type = t.attrsOf t.raw;
              readOnly = true;
              description = ''
                The raw outputs that were generated.
              '';
            };
          };
        };
      });
  };
}
