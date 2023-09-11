{config, ...}: {
  imports = [
    ./interface.nix
  ];

  config.public.name = config.name;
  config.public.version = config.version;
  config.public.${
    if config ? lock
    then "lock"
    else null
  } =
    config.lock.refresh;
  config.type = "derivation";
  config.drvPath = config.public.drvPath;
}
