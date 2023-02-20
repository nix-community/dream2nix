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
  illegalEnvNames =
    [
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
    ]
    ++ (
      l.map
      (phase: "${phase}Phase")
      ["configure" "build" "check" "install" "fixup" "unpack"]
    )
    ++ l.flatten (
      l.map
      (phase: ["pre${phase}" "post${phase}"])
      ["Configure" "Build" "Check" "Install" "Fixup" "Unpack"]
    );
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
      drv.drvAttrs
    );
  combineEnvs = envs:
    l.foldl'
    (
      all: env:
        all
        // env
        // {
          buildInputs = (all.buildInputs or []) ++ (env.buildInputs or []);
          nativeBuildInputs = (all.nativeBuildInputs or []) ++ (env.nativeBuildInputs or []);
        }
    )
    {}
    envs;
  _shellEnv = combineEnvs (l.map getEnvs drvs);
  shellEnv =
    _shellEnv
    // {
      inherit name;
      passthru.env = _shellEnv;
    };
in
  (mkShell.override {stdenv = (l.head drvs).stdenv;}) shellEnv
