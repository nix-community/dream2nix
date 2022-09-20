{
  # args
  drv,
  # d2n
  externals,
  # nixpkgs
  lib,
  stdenv,
  libiconv,
  ...
}: let
  l = lib // builtins;

  # function to merge two devshells
  mergeShellConfig = base: other: let
    c = base.config;
    oc = other.config;
    i = base.imports;
    oi = other.imports;
    hasCConfig = config: (config ? language) && (config.language ? c);
  in {
    config =
      c
      // oc
      // {
        packages = l.unique (c.packages ++ oc.packages);
        commands = l.unique (c.commands ++ oc.commands);
        env = l.unique (c.env ++ oc.env);
      }
      // l.optionalAttrs (hasCConfig c || hasCConfig oc) {
        language.c = let
          cConf = c.language.c;
          ocConf = oc.language.c;
        in {
          compiler = ocConf.compiler or cConf.compiler;
          libraries =
            l.unique ((cConf.libraries or []) ++ (ocConf.libraries or []));
          includes =
            l.unique ((cConf.includes or []) ++ (ocConf.includes or []));
        };
      };
    imports = l.unique (i ++ oi);
  };
  # creates a shell from a config
  mkShell = config: let
    shell = (externals.devshell.makeShell {configuration = config;}).shell;
  in
    shell
    // {
      passthru.config = config;
      combineWith = other:
        mkShell (mergeShellConfig config other.passthru.config);
    };
  # convenience utils for converting a nix attribute to a shell env
  # TODO: we could probably replace this with something from nixpkgs?
  toStr = v:
    if l.isBool v
    then l.boolToString v
    else l.toString v;
  toShellEnv = v:
    if l.isList v
    then "( ${l.concatStringsSep " " (l.map (v: ''"${toStr v}"'') v)} )"
    else l.toString v;
  # illegal env names to be removed and not be added to the devshell
  illegalEnvNames = [
    "all"
    "args"
    "drvPath"
    "outPath"
    "stdenv"
    "cargoArtifacts"
    "dream2nixVendorDir"
    "cargoVendorDir"
  ];
  isIllegalEnv = name: l.any (oname: name == oname) illegalEnvNames;
  inputs = (drv.buildInputs or []) ++ (drv.nativeBuildInputs or []);
  rustToolchain = drv.passthru.rustToolchain;
  # the config we will use
  conf = {
    config =
      {
        packages = inputs;
        commands = [
          {
            package = rustToolchain.cargoHostTarget or rustToolchain.cargo;
            name = "cargo";
            category = "rust";
            help = "Rust build tool";
          }
        ];
        env =
          # filter out attrsets, functions and illegal environment vars
          l.filter
          (env: (env != null) && (! isIllegalEnv env.name))
          (
            l.mapAttrsToList
            (
              n: v:
                if ! (l.isAttrs v || l.isFunction v)
                then {
                  name = n;
                  value = toShellEnv v;
                }
                else null
            )
            drv
          );
      }
      # only add c stuff *if* the stdenv has a c compiler
      # if the user wants to use stdenvNoCC this allows them to do it easily
      // l.optionalAttrs (drv.stdenv ? cc) {
        language.c = {
          compiler = drv.stdenv.cc;
          libraries = inputs ++ (lib.optional stdenv.isDarwin libiconv);
          includes = inputs;
        };
      };
    imports = [externals.devshell.imports.c];
  };
in
  mkShell conf
