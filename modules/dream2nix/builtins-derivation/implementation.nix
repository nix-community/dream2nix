{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  cfg = config.builtins-derivation;

  outputs = l.unique cfg.outputs;

  keepArg = key: val: val != null;

  finalArgs = l.filterAttrs keepArg cfg;

  # ensure that none of the env variables collide with the top-level options
  envChecked =
    l.mapAttrs
    (key: val:
      if config.builtins-derivation.${key} or false
      then throw (envCollisionError key)
      else val)
    config.env;

  # generates error message for env variable collision
  envCollisionError = key: ''
    Error while evaluating definitions for derivation ${config.name}
    The environment variable defined via `env.${key}' collides with the option builtins-derivation.`${key}'.
    Specify the top-level option instead, or rename the environment variable.
  '';
in {
  imports = [
    ../core
    ../package-func
  ];

  config.package-func.outputs = cfg.outputs;

  config.package-func.func = lib.mkDefault builtins.derivation;

  config.package-func.args =
    envChecked
    // finalArgs
    // {
      inherit outputs;
      inherit (config.public) name;
    };
}
