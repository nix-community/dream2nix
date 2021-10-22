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

      # extraArgs
      dev,
      optional,
      peer,
      ...
    }:

    let
      b = builtins;
      yarnLock = utils.readTextFile "${lib.elemAt inputDirectories 0}/yarn.lock";
      packageJSON = b.fromJSON (b.readFile "${lib.elemAt inputDirectories 0}/package.json");
      parser = import ../yarn-lock/parser.nix { inherit lib; inherit (externals) nix-parsec;};
      tryParse = parser.parseLock yarnLock;
      parsedLock =
        if tryParse.type == "success" then
          lib.foldAttrs (n: a: n // a) {} tryParse.value
        else
          let
            failureOffset = tryParse.value.offset;
          in
            throw "parser failed at: \n${lib.substring failureOffset 50 tryParse.value.str}";
    in
    
    utils.simpleTranslate translatorName rec {

      inputData = parsedLock;
      mainPackageName = packageJSON.name;
      mainPackageVersion = packageJSON.version;
      buildSystemName = "nodejs";

      buildSystemAttrs = {
        nodejsVersion = 14;
      };

      mainPackageDependencies =
        lib.mapAttrsToList
          (depName: depSemVer:
            let
              depYarnKey = "${depName}@${depSemVer}";
              dependencyAttrs =
                if ! inputData ? "${depYarnKey}" then
                  throw "Cannot find entry for top level dependency: '${depYarnKey}'"
                else
                  inputData."${depYarnKey}";
            in
              {
                name = depName;
                version = dependencyAttrs.version;
              }
          )
          (
            packageJSON.dependencies or {}
            //
            (lib.optionalAttrs dev (packageJSON.devDependencies or {}))
            //
            (lib.optionalAttrs peer (packageJSON.peerDependencies or {}))
          );

      serializePackages = inputData:
        lib.mapAttrsToList
          (yarnName: depAttrs: depAttrs // { inherit yarnName; })
          parsedLock;

      getOriginalID = dependencyObject:
        dependencyObject.yarnName;

      getName = dependencyObject:
        let
          version = lib.last (lib.splitString "@" dependencyObject.yarnName);
        in
          lib.removeSuffix "@${version}" dependencyObject.yarnName;

      getVersion = dependencyObject:
          dependencyObject.version;

      getDependencies = dependencyObject: getDepByNameVer: getDepByOriginalID:
        let
          dependencies =
            dependencyObject.dependencies or []
            ++ (lib.optionals optional (dependencyObject.optionalDependencies or []));
        in
          lib.forEach
            dependencies
            (dependency: 
              builtins.head (
                lib.mapAttrsToList
                  (name: value:
                    let
                      yarnName = "${name}@${value}";
                      depObject = getDepByOriginalID yarnName; 
                      version = depObject.version;
                    in
                      { inherit name version; }
                  )
                  dependency
              )
            );

      getSourceType = dependencyObject:
        if lib.hasInfix "@github:" dependencyObject.yarnName
            || lib.hasInfix "codeload.github.com/" dependencyObject.resolved then
          if dependencyObject ? integrity then
            b.trace "Warning: Using git despite integrity exists for ${getName dependencyObject}"
              "git"
          else
            "git"
        else if lib.hasInfix "@link:" dependencyObject.yarnName then
          "path"
        else
          "fetchurl";

      
      sourceConstructors = {
        git = dependencyObject:
          let
            gitUrlInfos = lib.splitString "/" dependencyObject.resolved;
            rev = lib.elemAt gitUrlInfos 6;
            owner = lib.elemAt gitUrlInfos 3;
            repo = lib.elemAt gitUrlInfos 4;
            version = dependencyObject.version;
          in
          {
            url = "https://github.com/${owner}/${repo}";
            inherit rev version;
          };

        path = dependencyObject:
          {
            version = dependencyObject.version;     
            path = lib.last (lib.splitString "@link:" dependencyObject.yarnName);
          };

        fetchurl = dependencyObject:
          {
            type = "fetchurl";
            version = dependencyObject.version;  
            hash =
              if dependencyObject ? integrity then
                dependencyObject.integrity
              else
                throw "Missing integrity for ${dependencyObject.yarnName}";
            url = lib.head (lib.splitString "#" dependencyObject.resolved);
          };
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

    dev = {
      description = "Whether to include development dependencies";
      type = "flag";
    };

    optional = {
      description = "Whether to include optional dependencies";
      type = "flag";
    };

    peer = {
      description = "Whether to include peer dependencies";
      type = "flag";
    };

  };
}
