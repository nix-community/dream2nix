{
  config,
  lib,
  ...
}: {
  imports = [
    ./interface.nix
    ../public
  ];

  config = {
    public = {
      name = lib.mkDefault config.name;
      version = lib.mkDefault config.version;
      ${
        if config ? lock
        then "lock"
        else null
      } =
        config.lock.refresh;
    };
    type = "derivation";
    inherit (config.public) drvPath;
  };
}
