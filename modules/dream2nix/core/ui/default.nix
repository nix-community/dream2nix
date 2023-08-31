{config, ...}: {
  imports = [
    ./interface.nix
  ];

  config.public.name = config.name;
  config.public.version = config.version;
}
