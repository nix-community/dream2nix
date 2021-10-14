{
  lib,
  pkgs,

  externals,
  translatorName,
  utils,
  ...
}:

{
  translate =
    {
      inputDirectories,
      inputFiles,

      dev,
      ...
    }:
    let
      inherit (pkgs) callPackage runCommand curl cacert racket;

      b = builtins;
      parser = import ./parser.nix { inherit lib; inherit (externals) nix-parsec; };

      rktInfo = utils.readTextFile "${lib.elemAt inputDirectories 0}/info.rkt";
      parsedInfo = parser.parseRacketInfo rktInfo;

      pkgCatalog = builtins.fromJSON
        (builtins.readFile (callPackage ./catalog.nix { inherit parser; }));

      mainPackage = parsedInfo.collection;
      mainPackageKey = "${mainPackage}#${parsedInfo.version}";

      #TODO: At the present there is a bug in the parser which fails if escaped strings \" are inside a quoted string
      parsedPkgs = parser.parseRacketPkgs pkgCatalog;

      deps = parsedInfo.deps;
      build-deps = parsedInfo.build-deps;

      getBasePackages = pkg:
        b.tail (lib.attrsets.mapAttrsToList (name: value: name ) (b.readDir "${pkg}/share/racket/pkgs"));

      basePackages = [ "racket" ] ++ (getBasePackages racket);

      convertToList = value:
        if b.typeOf value == "string" then [ value ] else value;

      checkForBasePackages = list:
        b.filter (x: b.typeOf x != "list")
          (lib.lists.subtractLists basePackages (convertToList list));

      # TODO: deal with dependencies that have versions eg.
      # (dependencies . (("base" #:version "7.6") ... ))
      # currently we are just ignoring anything that has a version :/
      extractSources = list:
        if b.length list == 0 then [] else
          let
            pkg = b.head list;
            tail = b.tail list;
            source = pkgCatalog.${pkg}.source;
            name = "${pkgCatalog.${pkg}.name}#${(b.substring 0 6 checksum)}";
            checksum = pkgCatalog.${pkg}.checksum;
            dependencies = convertToList pkgCatalog.${pkg}.dependencies;
            dependencies' = checkForBasePackages dependencies;
            gitUrlInfos = lib.splitString "/" source;
          in
            [
              (if lib.hasInfix "github" source || lib.hasInfix "gitlab" source
               then
                 let type = if lib.hasInfix "github" source then "github" else "gitlab";
                 in {
                   # A lot of packages do not have a versions instead use the git rev
                   name = {
                     inherit type;
                     rev = checksum;
                     owner = lib.elemAt gitUrlInfos 3;
                     #REVIEW: Does the `.git` suffix need to be trimmed?
                     repo = lib.elemAt gitUrlInfos 4;
                   };
                 }
               else
                 {
                   name = {
                     source = source;
                     #TODO: What does this look like if they are not hosted on github or gitlab?
                   };
                 }
              )
            ] ++ extractSources dependencies' ++ extractSources tail;

      sources = extractSources (convertToList deps);

      constructDependencyGraph = list:
        if b.length list == 0 then [ ]
        else
          let
            pkg = b.head list;
            tail = b.tail list;
            checksum = pkgCatalog.${pkg}.checksum;
            name = "${pkgCatalog.${pkg}.name}#${(b.substring 0 6 checksum)}";
            dependencies = convertToList pkgCatalog.${pkg}.dependencies;
            dependencies' = checkForBasePackages dependencies;
          in [
            name
            (constructDependencyGraph dependencies')
          ] ++ constructDependencyGraph tail;

      dependencyGraph = constructDependencyGraph deps;
    in

    rec {
      inherit sources;

      generic = {
        buildSystem = "racket";
        producedBy = translatorName;
        inherit mainPackage;
        inherit dependencyGraph;
        sourcesCombinedHash = null;
      };

      # build system specific attributes
      buildSystem = {

        # will this have any effect on the final output?
        racket = 8.0;
        inherit build-deps;
      };
    };


  # From a given list of paths, this function returns all paths which can be processed by this translator.
  # This allows the framework to detect if the translator is compatible with the given inputs
  # to automatically select the right translator.
  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = lib.filter
        (utils.containsMatchingFile [ ''info\.rkt'' ])
        args.inputDirectories;
      
      inputFiles = [];
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  specialArgs = {

    # Example: boolean option
    # Flags always default to 'false' if not specified by the user
    dev-dependenices = {
      description = "Include dev dependencies";
      type = "flag";
    };

    # Example: string option
    the-answer = {
      default = "42";
      description = "The Answer to the Ultimate Question of Life";
      examples = [
        "0"
        "1234"
      ];
      type = "argument";
    };

  };
}
