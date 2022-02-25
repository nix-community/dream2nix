{
  lib,
  ...
}:
let

  l = lib // builtins;


  # exported attributes
  dlib = {
    inherit
      calcInvalidationHash
      containsMatchingFile
      dirNames
      discoverers
      listDirs
      listFiles
      prepareSourceTree
      readTextFile
      translators
      sanitizeRelativePath
    ;
  };

  # other libs
  translators = import ./translators.nix { inherit dlib lib; };
  discoverers = import ../discoverers { inherit dlib lib; };


  # INTERNAL

  # prepare source tree for executing discovery phase
  # produces this structure:
  # {
  #   files = {
  #     "package.json" = {
  #       relPath = "package.json"
  #       fullPath = "${source}/package.json"
  #       content = ;
  #       jsonContent = ;
  #       tomlContent = ;
  #     }
  #   };
  #   directories = {
  #     "packages" = {
  #       relPath = "packages";
  #       fullPath = "${source}/packages";
  #       files = {
  #
  #       };
  #       directories = {
  #
  #       };
  #     };
  #   };
  # }
  prepareSourceTreeInternal = sourceRoot: relPath: name: depth:
    let
      relPath' = relPath;
      fullPath' = "${sourceRoot}/${relPath}";
      current = l.readDir fullPath';

      fileNames =
        l.filterAttrs (n: v: v == "regular") current;

      directoryNames =
        l.filterAttrs (n: v: v == "directory") current;

      makeNewPath = prefix: name:
        if prefix == "" then
          name
        else
          "${prefix}/name";

      directories =
        l.mapAttrs
          (dname: _:
            prepareSourceTreeInternal
              sourceRoot
              (makeNewPath relPath dname)
              dname
              (depth - 1))
          directoryNames;

      files =
        l.mapAttrs
          (fname: _: l.trace fname rec {
            name = fname;
            fullPath = "${fullPath'}/${fname}";
            relPath = makeNewPath relPath fname;
            content = readTextFile fullPath;
            jsonContent = l.fromJSON content;
            tomlContent = l.fromTOML content;
          })
          fileNames;

    in
      {
        inherit name files relPath;

        fullPath = fullPath';
      }
      # stop recursion if depth is reached
      // (l.optionalAttrs (depth > 0) {
        inherit directories;
      });


  # EXPORTED

  # calculate an invalidation hash for given source translation inputs
  calcInvalidationHash =
    {
      source,
      translator,
      translatorArgs,
    }:
    l.hashString "sha256" ''
      ${source}
      ${translator}
      ${l.toString
        (l.mapAttrsToList (k: v: "${k}=${l.toString v}") translatorArgs)}
    '';

  # Returns true if every given pattern is satisfied by at least one file name
  # inside the given directory.
  # Sub-directories are not recursed.
  containsMatchingFile = patterns: dir:
    l.all
      (pattern: l.any (file: l.match pattern file != null) (listFiles dir))
      patterns;

  # directory names of a given directory
  dirNames = dir: l.attrNames (l.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  listDirs = path: l.attrNames (l.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  listFiles = path: l.attrNames (l.filterAttrs (n: v: v == "regular") (builtins.readDir path));

  prepareSourceTree =
    {
      source,
      depth ? 3,
    }:
    prepareSourceTreeInternal source "" "" depth;

  readTextFile = file: l.replaceStrings [ "\r\n" ] [ "\n" ] (l.readFile file);

  sanitizeRelativePath = path:
    l.removePrefix "/" (l.toString (l.toPath "/${path}"));

in

dlib
