{
  builders,
  callPackageDream,
  ...
}: {
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
}
