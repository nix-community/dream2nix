{
  config,
  lib,
  specialArgs,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  mkDerivationOptions = import ../mkDerivation/options.nix {
    inherit dream2nix lib specialArgs;
  };
in {
  imports = [
    ../package-func/interface.nix
  ];

  options =
    mkDerivationOptions
    // {
      deps.stdenv = l.mkOption {
        type = t.raw;
        description = ''
          The stdenv used for building this package
        '';
      };
    };
}
