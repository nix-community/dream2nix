{
  # args
  name,
  depsDrv,
  mainDrv,
  # nixpkgs
  lib,
  libiconv,
  mkShell,
  cargo,
  ...
}: let
  l = lib // builtins;

  # illegal env names to be removed and not be added to the devshell
  illegalEnvNames =
    [
      "src"
      "name"
      "pname"
      "version"
      "args"
      "stdenv"
      "builder"
      "outputs"
      "phases"
      # cargo artifact and vendoring derivations
      # we don't need these in the devshell
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
      drv.config.mkDerivation
    );
  combineEnvs = envs:
    l.foldl'
    (
      all: env: let
        mergeInputs = name: (all.${name} or []) ++ (env.${name} or []);
      in
        all
        // env
        // {
          buildInputs = mergeInputs "buildInputs";
          nativeBuildInputs = mergeInputs "nativeBuildInputs";
          propagatedBuildInputs = mergeInputs "propagatedBuildInputs";
          propagatedNativeBuildInputs = mergeInputs "propagatedNativeBuildInputs";
        }
    )
    {}
    envs;
  _shellEnv = combineEnvs (l.map getEnvs [depsDrv mainDrv]);
  shellEnv =
    _shellEnv
    // {
      inherit name;
      passthru.env = _shellEnv;
      nativeBuildInputs = _shellEnv.nativeBuildInputs ++ [cargo];
    };
in
  (mkShell.override {inherit (mainDrv.out) stdenv;}) shellEnv
