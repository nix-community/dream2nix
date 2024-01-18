{
  config,
  lib,
  ...
}: {
  imports = [
    ./interface.nix
    ../public
  ];

  config.public.name = lib.mkDefault config.name;
  config.public.version = lib.mkDefault config.version;
  config.public.${
    if config ? lock
    then "lock"
    else null
  } =
    config.lock.refresh;
  config.type = "derivation";
  config.drvPath = config.public.drvPath;
}
