{
  pkgs,

  callPackageDream,
  externalSources,
  dream2nixWithExternals,
  translators,
  ...
}:
rec {
  apps = { inherit cli cli2 contribute install; };

  # the unified translator cli
  cli = callPackageDream (import ./cli) {};
  cli2 = callPackageDream (import ./cli2) {};

  # the contribute cli
  contribute = callPackageDream (import ./contribute) {};

  # install the framework to a specified location by copying the code
  install = callPackageDream (import ./install) {};
}
