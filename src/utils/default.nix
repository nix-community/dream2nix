{
  bash,
  coreutils,
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

  overrideUtils = callPackageDream ./override.nix {};

  dreamLockUtils = callPackageDream ./dream-lock.nix {};

  translatorUtils = callPackageDream ./translator.nix {};

in

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

    export PATH="${lib.makeBinPath availablePrograms}"
    tmpdir=$(${coreutils}/bin/mktemp -d)
    cd $tmpdir

    ${script}

    cd
    ${coreutils}/bin/rm -rf $tmpdir
  '';

}
