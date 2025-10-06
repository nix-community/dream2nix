# Module to provide an interface for integrating derivation builder functions
#   like for example, mkDerivation, buildPythonPackage, etc...
{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    package-func = {
      outputs = l.mkOption {
        type = t.listOf t.str;
        internal = true;
        description = "Outputs of the derivation this package function produces";
      };

      args = l.mkOption {
        type = t.lazyAttrsOf (t.either (t.listOf t.raw) t.anything);
        internal = true;
        description = "The arguments which will be passed to `package-func.func`";
      };

      func = l.mkOption {
        type = t.raw;
        internal = true;
        description = "Will be called with `package-func.args` in order to derive `package-func.result`";
      };

      result = l.mkOption {
        type = t.raw;
        internal = true;
        description = ''
          The result of calling the final derivation function.
          This is not necessarily the same as `final.package`. The function output might not be compatible to the interface of `final.package` and additional logic might be needed to create `final.package`.
        '';
      };
    };

    # add an option for each output, eg. out, bin, lib, etc...
    # TODO: these dynamic options cannot be rendered into a manual.
    #   -> removing them for now
    #   -> maybe refactor `public` to be a submodule which is dynamically created
    #      This would not improve the manual but allow for type checking
    # options.public = l.genAttrs outputs (output:
    #   l.mkOption {
    #     type = t.path;
    #   });
  };
}
