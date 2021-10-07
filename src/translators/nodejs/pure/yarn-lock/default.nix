{
  lib,

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
      ...
    }:
    let
      b = builtins;
      yarnLock = utils.readTextFile "${lib.elemAt inputDirectories 0}/yarn.lock";
      packageJSON = b.fromJSON (b.readFile "${lib.elemAt inputDirectories 0}/package.json");
      parser = import ./parser.nix { inherit lib; inherit (externals) nix-parsec;};
      tryParse = parser.parseLock yarnLock;

      mainPackageName = packageJSON.name;
      mainPackageKey = "${mainPackageName}#${packageJSON.version}";
      
      parsedLock =
        if tryParse.type == "success" then
          lib.foldAttrs (n: a: n // a) {} tryParse.value
        else
          let
            failureOffset = tryParse.value.offset;
          in
            throw "parser failed at: \n${lib.substring failureOffset 50 tryParse.value.str}";
      nameFromLockName = lockName:
        let
          version = lib.last (lib.splitString "@" lockName);
        in
          lib.removeSuffix "@${version}" lockName;
      sources = lib.mapAttrs' (dependencyName: dependencyAttrs:
        let
          name = nameFromLockName dependencyName;
        in
          lib.nameValuePair ("${name}#${dependencyAttrs.version}") (
          if ! lib.hasInfix "@github:" dependencyName then
            {
              version = dependencyAttrs.version;  
              hash = dependencyAttrs.integrity;
              url = lib.head (lib.splitString "#" dependencyAttrs.resolved);
              type = "fetchurl";
            }
          else if lib.hasInfix "@link:" dependencyName then
            {
              version = dependencyAttrs.version;     
              path = lib.last (lib.splitString "@link:" dependencyName);
              type = "path";
            }
          else
            let
               gitUrlInfos = lib.splitString "/" dependencyAttrs.resolved;
            in
            {
              type = "github";
              rev = lib.elemAt gitUrlInfos 6;
              owner = lib.elemAt gitUrlInfos 3;
              repo = lib.elemAt gitUrlInfos 4;
            }
          )) parsedLock;
      dependencyGraph =
        (lib.mapAttrs'
          (dependencyName: dependencyAttrs:
            let
              name = nameFromLockName dependencyName;
              dependencies = dependencyAttrs.dependencies or [] ++ dependencyAttrs.optionalDependencies or [];
              graph = lib.forEach dependencies (dependency: 
                builtins.head (
                  lib.mapAttrsToList
                    (name: value:
                      let
                        yarnName = "${name}@${value}";
                        version = parsedLock."${yarnName}".version;
                      in
                      "${name}#${version}"
                    )
                    dependency
                )
              );
            in
              lib.nameValuePair ("${name}#${dependencyAttrs.version}") graph
          )
          parsedLock
        )
        //
        {
          "${mainPackageName}" =
            lib.mapAttrsToList
              (depName: depSemVer:
                let
                  depYarnKey = "${depName}@${depSemVer}";
                  dependencyAttrs =
                    if ! parsedLock ? "${depYarnKey}" then
                      throw "Cannot find entry for top level dependency: '${depYarnKey}'"
                    else
                      parsedLock."${depYarnKey}";
                in
                  "${depName}#${dependencyAttrs.version}"
              )
              packageJSON.dependencies;
        };


    in
    # TODO: produce dream lock like in /specifications/dream-lock-example.json
      
    rec {
      inherit sources;

      generic = {
        buildSystem = "nodejs";
        producedBy = translatorName;
        mainPackage = mainPackageName;
        inherit dependencyGraph;
        sourcesCombinedHash = null;
      };

      # build system specific attributes
      buildSystem = {

        # example
        nodejsVersion = 14;
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
        (utils.containsMatchingFile [ ''.*yarn\.lock'' ''.*package.json'' ])
        args.inputDirectories;

      inputFiles = [];
    };


  # If the translator requires additional arguments, specify them here.
  # There are only two types of arguments:
  #   - string argument (type = "argument")
  #   - boolean flag (type = "flag")
  # String arguments contain a default value and examples. Flags do not.
  specialArgs = {

    # optionalDependencies = {
    #   description = "Whether to include optional dependencies";
    #   type = "flag";
    # };

  };
}
