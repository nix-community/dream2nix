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
      b = builtins;
      rktInfo = utils.readTextFile "${lib.elemAt inputDirectories 0}/info.rkt";
      parser = import ./parser.nix { inherit lib; inherit (externals) nix-parsec; };
      parsedInfo = parser.parseRacketInfo rktInfo;

      #TODO: Handle case where there is more than one collection
      mainPackage = parsedInfo.collection;
      mainPackageKey = "${mainPackage}#${parsedInfo.version}";

      #TODO: This is sadly impure, getting around this by using wayback machine for now
      # Would a way around this be to cache these changes ourselves in a better way than i am doing here?
      # eg Have a github action that checks for changes to this file and caches it in dream to Nix with a date tag?
      # or should this be converted into a impure translator...
      pkgCatalog = pkgs.runCommand "fetch-racket-package-index" {
        outputHash = "+U8FvM5Sf8QNJdH/L1V4L8nS49NAFZZxK0fnFRuLC/E=";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        buildInputs = [ pkgs.curl ];
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      } ''
          curl https://web.archive.org/web/20211013170533/https://pkgs.racket-lang.org/pkgs-all --output $out
        '';

      #TODO: At the present there is a bug in the parser which fails if escaped strings \" are inside a quoted string
      parsedPkgs = parser.parseRacketPkgs pkgCatalog;

      deps = parsedInfo.deps;
      build-deps = parsedInfo.build-deps;

      getBasePackages = pkg:
        b.tail (lib.attrsets.mapAttrsToList (name: value: name ) (b.readDir "${pkg}/share/racket/pkgs"));

      basePackages = [ "racket" ] ++ (getBasePackages pkgs.racket);

      convertToList = value:
        if b.typeOf value == "string" then [ value ] else value;

      # TODO: deal with dependencies that have versions eg.
      # (dependencies . (("base" #:version "7.6") ... ))
      # currently we are just ignoring anything that has a version :/
      extractSources = list:
        let list' = builtins.filter (x: b.typeOf x != "list")
          (lib.lists.subtractLists basePackages (convertToList list)); in
        if builtins.length list' == 0 then [] else
          let
            pkg = builtins.head list';
            tail = builtins.tail list';
            source = pkgCatalog.${pkg}.source;
            name = pkgCatalog.${pkg}.name;
            checksum = pkgCatalog.${pkg}.checksum;
            dependencies = convertToList pkgCatalog.${pkg}.dependencies;
            gitUrlInfos = lib.splitString "/" source;
          in
            [
              (if lib.hasInfix "github" source
               then
                 {
                   type = "github";
                   rev = checksum;
                   owner = lib.elemAt gitUrlInfos 3;
                   #REVIEW: Does the `.git` suffix need to be trimmed?
                   repo = lib.elemAt gitUrlInfos 4;
                 }
               else
                 {
                   name = name;
                   source = source;
                   #TODO: What does this look like if they are not hosted on github?
                   # eg. there are some on git repos on gitlab
                 }
              )
            ] ++ extractSources dependencies ++ extractSources tail;

      sources = extractSources (convertToList deps);

      constructDependencyGraph = list:
        if b.length list == 0 then [ ]
        else
          let
            pkg = b.head list;
            tail = b.tail list;
            name = pkgCatalog.${pkg}.name;
            dependencies = convertToList pkgCatalog.${pkg}.dependencies;
          in [
            name
            (constructDependencyGraph dependencies)
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
