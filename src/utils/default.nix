{
  bash,
  coreutils,
  fetchzip,
  lib,
  nix,
  pkgs,
  runCommand,
  writeScript,

  # dream2nix inputs
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

  dreamLock = dreamLockUtils;

  inherit (dreamLockUtils) readDreamLock;

  readTextFile = file: lib.replaceStrings [ "\r\n" ] [ "\n" ] (b.readFile file);

  traceJ = toTrace: eval: b.trace (b.toJSON toTrace) eval;

  isFile = path: (builtins.readDir (b.dirOf path))."${b.baseNameOf path}" ==  "regular";

  isDir = path: (builtins.readDir (b.dirOf  path))."${b.baseNameOf path}" ==  "directory";

  listFiles = path: lib.attrNames (lib.filterAttrs (n: v: v == "regular") (builtins.readDir path));

  listDirs = path: lib.attrNames (lib.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  toDrv = path: runCommand "some-drv" {} "cp -r ${path} $out";

  # directory names of a given directory
  dirNames = dir: lib.attrNames (lib.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  # Returns true if every given pattern is satisfied by at least one file name
  # inside the given directory.
  # Sub-directories are not recursed.
  containsMatchingFile = patterns: dir:
    lib.all
      (pattern: lib.any (file: b.match pattern file != null) (listFiles dir))
      patterns;

  # allow a function to receive its input from an environment variable
  # whenever an empty set is passed
  makeCallableViaEnv = func: args:
    if args == {} then
      func (builtins.fromJSON (builtins.readFile (builtins.getEnv "FUNC_ARGS")))
    else
      func args;

  # hash the contents of a path via `nix hash-path`
  hashPath = algo: path:
    let
      hashFile = runCommand "hash-${algo}" {} ''
        ${nix}/bin/nix hash-path ${path} | tr --delete '\n' > $out
      '';
    in
      b.readFile hashFile;

  # builder to create a shell script that has it's own PATH
  writePureShellScript = availablePrograms: script: writeScript "script.sh" ''
    #!${bash}/bin/bash
    set -Eeuo pipefail

    export PATH="${lib.makeBinPath availablePrograms}"
    export NIX_PATH=nixpkgs=${pkgs.path}

    tmpdir=$(${coreutils}/bin/mktemp -d)
    cd $tmpdir

    ${script}

    cd
    ${coreutils}/bin/rm -rf $tmpdir
  '';

  extractSource =
    {
      source,
    }:
      # fetchzip can extract tarballs as well
      (fetchzip { url="file:${source}"; }).overrideAttrs (old: {
        name = "${(source.name or "")}extracted";
        outputHash = null;
        postFetch =
          ''
            if test -d ${source}; then
              ln -s ${source} $out
              exit 0
            fi
          ''
          + old.postFetch;
      });

  sanitizeDerivationName = name:
    lib.replaceStrings [ "@" "/" ] [ "__at__" "__slash__" ] name;

  nameVersionPair = name: version:
    { inherit name version; };

  # determines if version v1 is greater than version v2
  versionGreater = v1: v2:
    versionGreaterList
      (lib.splitString "." v1)
      (lib.splitString "." v2);

  # internal helper for 'versionGreater'
  versionGreaterList = v1: v2:
    let
      head1 = b.head v1;
      head2 = b.head v2;
      n1 =
        if builtins.match ''[[:digit:]]*'' head1 != null then
          lib.toInt head1
        else
          0;
      n2 = if builtins.match ''[[:digit:]]*'' head2 != null then
          lib.toInt head2
        else
          0;
    in
      if n1 > n2 then
        true
      else
        # end recursion condition
        if b.length v1 == 1 || b.length v1 == 1 then
          false
        else
          # continue recursion
          versionGreaterList (b.tail v1) (b.tail v2);

  # picks the latest version from a list of version strings
  latestVersion = versions:
    b.head
      (lib.sort
        (v1: v2: versionGreater v1 v2)
        versions);

  satisfiesSemver = poetry2nixSemver.satisfiesSemver;

  # like nixpkgs recursiveUpdateUntil, but the depth of the
  recursiveUpdateUntilDepth = depth: lhs: rhs:
    lib.recursiveUpdateUntil (path: l: r: (b.length path) > depth) lhs rhs;

}
