{
  lib,
  config ? (import ../utils/config.nix).loadConfig {},
  ...
}: let
  l = lib // builtins;

  # exported attributes
  dlib = {
    inherit
      calcInvalidationHash
      callViaEnv
      containsMatchingFile
      dirNames
      discoverers
      latestVersion
      listDirs
      listFiles
      nameVersionPair
      prepareSourceTree
      readTextFile
      recursiveUpdateUntilDepth
      translators
      sanitizeDerivationName
      sanitizeRelativePath
      traceJ
      ;

    inherit
      (parseUtils)
      identifyGitUrl
      parseGitUrl
      ;
  };

  # other libs
  translators = import ./translators.nix {inherit dlib lib;};
  discoverers = import ../discoverers {inherit config dlib lib;};

  parseUtils = import ./parsing.nix {inherit lib;};

  # INTERNAL

  # Calls any function with an attrset arugment, even if that function
  # doesn't accept an attrset argument, in which case the arguments are
  # recursively applied as parameters.
  # For this to work, the function parameters defined by the called function
  # must always be ordered alphabetically.
  callWithAttrArgs = func: args: let
    applyParamsRec = func: params:
      if l.length params == 1
      then func (l.head params)
      else
        applyParamsRec
        (func (l.head params))
        (l.tail params);
  in
    if lib.functionArgs func == {}
    then applyParamsRec func (l.attrValues args)
    else func args;

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
  prepareSourceTreeInternal = sourceRoot: relPath: name: depth: let
    relPath' = relPath;
    fullPath' = "${sourceRoot}/${relPath}";
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

  # determines if version v1 is greater than version v2
  versionGreater = v1: v2: l.compareVersions v1 v2 == 1;

  # EXPORTED

  # calculate an invalidation hash for given source translation inputs
  calcInvalidationHash = {
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

  # call a function using arguments defined by the env var FUNC_ARGS
  callViaEnv = func: let
    funcArgs = l.fromJSON (l.readFile (l.getEnv "FUNC_ARGS"));
  in
    callWithAttrArgs func funcArgs;

  # Returns true if every given pattern is satisfied by at least one file name
  # inside the given directory.
  # Sub-directories are not recursed.
  containsMatchingFile = patterns: dir:
    l.all
    (pattern: l.any (file: l.match pattern file != null) (listFiles dir))
    patterns;

  # directory names of a given directory
  dirNames = dir: l.attrNames (l.filterAttrs (name: type: type == "directory") (builtins.readDir dir));

  # picks the latest version from a list of version strings
  latestVersion = versions:
    l.head
    (lib.sort versionGreater versions);

  listDirs = path: l.attrNames (l.filterAttrs (n: v: v == "directory") (builtins.readDir path));

  listFiles = path: l.attrNames (l.filterAttrs (n: v: v == "regular") (builtins.readDir path));

  nameVersionPair = name: version: {inherit name version;};

  prepareSourceTree = {
    source,
    depth ? 10,
  }:
    prepareSourceTreeInternal source "" "" depth;

  readTextFile = file: l.replaceStrings ["\r\n"] ["\n"] (l.readFile file);

  # like nixpkgs recursiveUpdateUntil, but with the depth as a stop condition
  recursiveUpdateUntilDepth = depth: lhs: rhs:
    lib.recursiveUpdateUntil (path: _: _: (l.length path) > depth) lhs rhs;

  sanitizeDerivationName = name:
    lib.replaceStrings ["@" "/"] ["__at__" "__slash__"] name;

  sanitizeRelativePath = path:
    l.removePrefix "/" (l.toString (l.toPath "/${path}"));

  traceJ = toTrace: eval: l.trace (l.toJSON toTrace) eval;
in
  dlib
