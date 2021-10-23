{
  bash,
  coreutils,
  fetchzip,
  lib,
  nix,
  runCommand,
  writeScriptBin,

  # dream2nix inputs
  callPackageDream,
  ...
}:
let

  b = builtins;
  
  dreamLockUtils = callPackageDream ./dream-lock.nix {};

  overrideUtils = callPackageDream ./override.nix {};

  parseUtils = callPackageDream ./parsing.nix {};

  translatorUtils = callPackageDream ./translator.nix {};

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

  isFile = path: (builtins.readDir (b.dirOf path))."${b.baseNameOf path}" ==  "regular";

  isDir = path: (builtins.readDir (b.dirOf  path))."${b.baseNameOf path}" ==  "directory";

  listFiles = path: lib.attrNames (lib.filterAttrs (n: v: v == "regular") (builtins.readDir path));

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
  writePureShellScript = availablePrograms: script: writeScriptBin "run" ''
    #!${bash}/bin/bash
    set -Eeuo pipefail

    export PATH="${lib.makeBinPath availablePrograms}"
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
  

}
