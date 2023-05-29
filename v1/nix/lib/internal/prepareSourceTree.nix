{lib, ...}: let
  l = builtins // lib;

  /*
  Transforms a source tree into a nix attrset for simplicity and performance.
  It's simpler to traverse an attrset than having to readDir manually.
  It's more performant because it allows to parse a json or toml by accessing
    attributes like `.jsonContent` or `.tomlContent` which ensures that the file
    is only parsed once, even if the parsed content is used in multiple places.

  produces this structure:
  {
    files = {
      "package.json" = {
        relPath = "package.json"
        fullPath = "${source}/package.json"
        content = ;
        jsonContent = ;
        tomlContent = ;
      }
    };
    directories = {
      "packages" = {
        relPath = "packages";
        fullPath = "${source}/packages";
        files = {

        };
        directories = {

        };
      };
    };
  }
  */
  prepareSourceTree = {
    source,
    depth ? 10,
  }:
    prepareSourceTreeInternal source "" "" depth;

  readTextFile = file: l.replaceStrings ["\r\n"] ["\n"] (l.readFile file);

  prepareSourceTreeInternal = sourceRoot: relPath: name: depth: let
    relPath' = relPath;
    fullPath' = "${toString sourceRoot}/${relPath}";
    current = l.readDir fullPath';

    fileNames =
      l.filterAttrs (n: v: v == "regular") current;

    directoryNames =
      l.filterAttrs (n: v: v == "directory") current;

    makeNewPath = prefix: name:
      if prefix == ""
      then name
      else "${prefix}/${name}";

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
      (fname: _: rec {
        name = fname;
        fullPath = "${fullPath'}/${fname}";
        relPath = makeNewPath relPath' fname;
        content = readTextFile fullPath;
        jsonContent = l.fromJSON content;
        tomlContent = l.fromTOML content;
      })
      fileNames;

    # returns the tree object of the given sub-path
    getNodeFromPath = path: let
      cleanPath = l.removePrefix "/" path;
      pathSplit = l.splitString "/" cleanPath;
      dirSplit = l.init pathSplit;
      leaf = l.last pathSplit;
      error = throw ''
        Failed while trying to navigate to ${path} from ${fullPath'}
      '';

      dirAttrPath =
        l.init
        (l.concatMap
          (x: [x] ++ ["directories"])
          dirSplit);

      dir =
        if (l.length dirSplit == 0) || dirAttrPath == [""]
        then self
        else if ! l.hasAttrByPath dirAttrPath directories
        then error
        else l.getAttrFromPath dirAttrPath directories;
    in
      if path == ""
      then self
      else if dir ? directories."${leaf}"
      then dir.directories."${leaf}"
      else if dir ? files."${leaf}"
      then dir.files."${leaf}"
      else error;

    self =
      {
        inherit files getNodeFromPath name relPath;

        fullPath = fullPath';
      }
      # stop recursion if depth is reached
      // (l.optionalAttrs (depth > 0) {
        inherit directories;
      });
  in
    self;
in
  prepareSourceTree
