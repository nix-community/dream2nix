{
  lib,
  config,
  ...
}: {
  subsystems.nodejs = {
    discoverers = {
      # default = lib.traceVal (import ./discoverers/default.nix);
      default = ./discoverers;
    };

    translators = {
      package-json = ./translators/impure/package-json;

      package-lock = ./translators/pure/package-lock;
      # yarn-lock    = ./translators/pure/yarn-lock;
    };

    # fetchers = [
    #   import ./fetchers/default.nix
    # ];

    # builders = [
    #   import ./builders/default.nix
    # ];
  };
}
