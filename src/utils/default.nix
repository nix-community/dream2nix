{
  bash,
  coreutils,
  dlib,
  fetchzip,
  lib,
  nix,
  pkgs,
  runCommand,
  stdenv,
  writeScript,

  # dream2nix inputs
  apps,
  callPackageDream,
  externalSources,
  ...
}:
let

  b = builtins;

  dreamLockUtils = callPackageDream ./dream-lock.nix {};

  overrideUtils = callPackageDream ./override.nix {};

  parseUtils = callPackageDream ./parsing.nix {};

  translatorUtils = callPackageDream ./translator.nix {};

  poetry2nixSemver = import "${externalSources.poetry2nix}/semver.nix" {
    inherit lib;
    # copied from poetry2nix
    ireplace = idx: value: list: (
      lib.genList
        (i: if i == idx then value else (b.elemAt list i))
        (b.length list)
    );
  };

in

parseUtils
//
overrideUtils
//
translatorUtils
//
rec {

  inherit (dlib)
    dirNames
    listDirs
    listFiles
    readTextFile
  ;

  dreamLock = dreamLockUtils;

  inherit (dreamLockUtils) readDreamLock;

  traceJ = toTrace: eval: b.trace (b.toJSON toTrace) eval;

  isFile = path: (builtins.readDir (b.dirOf path))."${b.baseNameOf path}" ==  "regular";

  isDir = path: (builtins.readDir (b.dirOf  path))."${b.baseNameOf path}" ==  "directory";

  toDrv = path: runCommand "some-drv" {} "cp -r ${path} $out";

  # Calls any function with an attrset arugment, even if that function
  # doesn't accept an attrset argument, in which case the arguments are
  # recursively applied as parameters.
  # For this to work, the function parameters defined by the called function
  # must always be ordered alphabetically.
  callWithAttrArgs = func: args:
    let
      applyParamsRec = func: params:
        if b.length params == 1 then
          func (b.head params)
        else
          applyParamsRec
            (func (b.head params))
            (b.tail params);

    in
      if lib.functionArgs func == {} then
        applyParamsRec func (b.attrValues args)
      else
        func args;

  # call a function using arguments defined by the env var FUNC_ARGS
  callViaEnv = func:
    let
      funcArgs = b.fromJSON (b.readFile (b.getEnv "FUNC_ARGS"));
    in
      callWithAttrArgs func funcArgs;

  # hash the contents of a path via `nix hash path`
  hashPath = algo: path:
    let
      hashPath = runCommand "hash-${algo}" {} ''
        ${nix}/bin/nix hash path ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashPath;

  # hash a file via `nix hash file`
  hashFile = algo: path:
    let
      hashFile = runCommand "hash-${algo}" {} ''
        ${nix}/bin/nix hash file ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashFile;

  # builder to create a shell script that has it's own PATH
  writePureShellScript = availablePrograms: script: writeScript "script.sh" ''
    #!${bash}/bin/bash
    set -Eeuo pipefail

    export PATH="${lib.makeBinPath availablePrograms}"
    export NIX_PATH=nixpkgs=${pkgs.path}
    export WORKDIR="$PWD"

    tmpdir=$(${coreutils}/bin/mktemp -d)
    cd $tmpdir

    ${script}

    cd
    ${coreutils}/bin/rm -rf $tmpdir
  '';

  extractSource =
    {
      source,
      dir ? "",
    }:
    stdenv.mkDerivation {
      name = "${(source.name or "")}-extracted";
      src = source;
      inherit dir;
      phases = [ "unpackPhase" ];
      dontInstall = true;
      dontFixup = true;
      unpackCmd =
        if lib.hasSuffix ".tgz" source.name then
          ''
            tar --delay-directory-restore -xf $src

            # set executable flag only on directories
            chmod -R +X .
          ''
        else
          null;
      # sometimes tarballs do not end with .tar.??
      preUnpack = ''
        unpackFallback(){
          local fn="$1"
          tar xf "$fn"
        }

        unpackCmdHooks+=(unpackFallback)
      '';
      postUnpack = ''
        echo postUnpack
        mv "$sourceRoot/$dir" $out
        exit
      '';
    };

  sanitizeDerivationName = name:
    lib.replaceStrings [ "@" "/" ] [ "__at__" "__slash__" ] name;

  nameVersionPair = name: version:
    { inherit name version; };

  # determines if version v1 is greater than version v2
  versionGreater = v1: v2: b.compareVersions v1 v2 == 1;

  # picks the latest version from a list of version strings
  latestVersion = versions:
    b.head
      (lib.sort versionGreater versions);

  satisfiesSemver = poetry2nixSemver.satisfiesSemver;

  # like nixpkgs recursiveUpdateUntil, but with the depth as a stop condition
  recursiveUpdateUntilDepth = depth: lhs: rhs:
    lib.recursiveUpdateUntil (path: l: r: (b.length path) > depth) lhs rhs;

  # a script that produces and dumps the dream-lock json for a given source
  makePackageLockScript =
    {
      packagesDir,
      source,
      translator,
      translatorArgs,
    }:
    writePureShellScript
      []
      ''
        cd $WORKDIR
        ${apps.cli.program} add ${source} \
          --force \
          --no-default-nix \
          --translator ${translator} \
          --invalidation-hash ${dlib.calcInvalidationHash {
            inherit source translator translatorArgs;
          }} \
          --packages-root $WORKDIR/${packagesDir} \
          ${lib.concatStringsSep " \\\n"
            (lib.mapAttrsToList
              (key: val: "--arg ${key}=${b.toString val}")
              translatorArgs)}
      '';
}
