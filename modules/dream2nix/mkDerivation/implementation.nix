{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;

  cfg = config.mkDerivation;

  outputs = l.unique cfg.outputs;

  keepArg = key: val: val != null;

  finalArgs = l.filterAttrs keepArg cfg;

  # ensure that none of the env variables collide with the top-level options
  envChecked =
    l.mapAttrs
    (key: val:
      if config.mkDerivation ? ${key}
      then throw (envCollisionError key)
      else val)
    config.env;

  # generates error message for env variable collision
  envCollisionError = key: ''
    Error while evaluating definitions for derivation ${config.name}
    The environment variable defined via `env.${key}' collides with the option mkDerivation.`${key}'.
    Specify the top-level option instead, or rename the environment variable.
  '';

  public =
    # meta
    (l.optionalAttrs (cfg.passthru ? meta) {
      inherit (cfg.passthru) meta;
    })
    # tests
    // (l.optionalAttrs (cfg.passthru ? tests) {
      inherit (cfg.passthru) tests;
    });
in {
  imports = [
    ../core
    ../package-func/implementation.nix
  ];

  config.package-func.outputs = cfg.outputs;

  config.package-func.func = lib.mkDefault config.deps.stdenv.mkDerivation;

  # add mkDerivation specific derivation attributes
  config.public = public;

  config.package-func.args =
    envChecked
    // finalArgs
    // {
      inherit outputs;
      inherit (config.public) version;
      pname = config.name;
    };

  config.deps = {nixpkgs, ...}: {
    stdenv = lib.mkOverride 1050 nixpkgs.stdenv;
  };
}
