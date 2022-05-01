{
  config,
  dlib,
  builders,
  callPackageDream,
  ...
}: let
  l = dlib.lib;

  builtinBuilders = {
    python = rec {
      default = simpleBuilder;

      simpleBuilder = callPackageDream ./python/simple-builder {};
    };

    nodejs = rec {
      default = granular;

      node2nix = callPackageDream ./nodejs/node2nix {};

      granular = callPackageDream ./nodejs/granular {inherit builders;};
    };

    rust = rec {
      default = buildRustPackage;

      buildRustPackage = callPackageDream ./rust/build-rust-package {};

      # this builder requires IFD!
      crane = callPackageDream ./rust/crane {};
    };
  };

  extendedBuilders = l.mapAttrs (name: subsystem: let
    default = subsystem.default or null;
    instantiated =
      l.mapAttrsToList
      (name: builder: let
        value = callPackageDream builder {};
      in (
        if default == builder
        then [
          {inherit name value;}
          {
            name = "default";
            inherit value;
          }
        ]
        else [{inherit name value;}]
      ))
      subsystem;
  in
    l.listToAttrs (l.flatten instantiated))
  config.builders or {};

  allBuilders = builtinBuilders // extendedBuilders;
in
  allBuilders
