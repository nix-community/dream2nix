{
  # args
  drvs,
  name,
  # nixpkgs
  lib,
  libiconv,
  mkShell,
  ...
}: let
  l = lib // builtins;

  # illegal env names to be removed and not be added to the devshell
  illegalEnvNames = [
    "name"
    "pname"
    "version"
    "all"
    "args"
    "drvPath"
    "drvAttrs"
    "outPath"
    "stdenv"
    "cargoArtifacts"
    "dream2nixVendorDir"
    "cargoVendorDir"
  ];
  isIllegalEnv = name: l.elem name illegalEnvNames;
  getEnvs = drv:
  # filter out attrsets, functions and illegal environment vars
    l.filterAttrs
    (name: env: (env != null) && (! isIllegalEnv name))
    (
      l.mapAttrs
      (
        n: v:
          if ! (l.isAttrs v || l.isFunction v)
          then v
          else null
      )
      drv
    );
  combineEnvs = envs:
    l.foldl'
    (
      all: env:
        all
        // env
        // {
          packages = (all.packages or []) ++ (env.packages or []);
          buildInputs = (all.buildInputs or []) ++ (env.buildInputs or []);
          nativeBuildInputs = (all.nativeBuildInputs or []) ++ (env.nativeBuildInputs or []);
          propagatedBuildInputs = (all.propagatedBuildInputs or []) ++ (env.propagatedBuildInputs or []);
          propagatedNativeBuildInputs = (all.propagatedNativeBuildInputs or []) ++ (env.propagatedNativeBuildInputs or []);
        }
    )
    {}
    envs;
  shellEnv =
    (combineEnvs (l.map getEnvs drvs))
    // {
      inherit name;
    };
in
  (mkShell.override {stdenv = (l.head drvs).stdenv;}) shellEnv
