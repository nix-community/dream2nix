{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  common-options = import ../derivation-common/options.nix {inherit lib;};

  builtin-derivation-options = {
    # basic arguments
    builder = lib.mkOption {
      type = t.oneOf [t.str t.path t.package];
    };
    system = lib.mkOption {
      type = t.str;
    };
  };
in {
  imports = [
    ../package-func/interface.nix
  ];

  options.builtins-derivation = common-options // builtin-derivation-options;
}
