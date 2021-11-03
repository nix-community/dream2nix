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
      name,
      noDev,
      peer,
      ...
    }:

    let
      b = builtins;
      dev = ! noDev;
  
      sourceDir = lib.elemAt inputDirectories 0;
      yarnLock = utils.readTextFile "${sourceDir}/yarn.lock";
      packageJSON = b.fromJSON (b.readFile "${sourceDir}/package.json");
      parser = import ../yarn-lock/parser.nix
        { inherit lib; inherit (externals) nix-parsec;};

      tryParse = parser.parseLock yarnLock;
      parsedLock =
        if tryParse.type == "success" then
          lib.foldAttrs (n: a: n // a) {} tryParse.value
        else
          let
            failureOffset = tryParse.value.offset;
          in
            throw ''
              parser failed at:
              ${lib.substring failureOffset 50 tryParse.value.str}
            '';
    in
    
    utils.simpleTranslate translatorName rec {

      inputData = parsedLock;

      mainPackageName =
        packageJSON.name or
          (if name != "{automatic}" then name else
            throw (
              "Could not identify package name. "
              + "Please specify extra argument 'name'"
            ));

      mainPackageVersion = packageJSON.version or "unknown";

      subsystemName = "nodejs";

      subsystemAttrs = {
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
        if lib.hasInfix "@git+" dependencyObject.yarnName then
          lib.head (lib.splitString "@git+" dependencyObject.yarnName)
        else
          let
            version = lib.last (lib.splitString "@" dependencyObject.yarnName);
          in
            lib.removeSuffix "@${version}" dependencyObject.yarnName;

      getVersion = dependencyObject:
          dependencyObject.version;

      getDependencies = dependencyObject: getDepByNameVer: dependenciesByOriginalID:
        let
          dependencies =
            dependencyObject.dependencies or []
            ++ dependencyObject.optionalDependencies or [];
        in
          lib.forEach
            dependencies
            (dependency: 
              builtins.head (
                lib.mapAttrsToList
                  (name: versionSpec:
                    let
                      yarnName = "${name}@${versionSpec}";
                      depObject = dependenciesByOriginalID."${yarnName}"; 
                      version = depObject.version;
                    in
                      if ! dependenciesByOriginalID ? ${yarnName} then
                        # handle missing lock file entry
                        let
                          versionMatch =
                            b.match ''.*\^([[:digit:]|\.]+)'' versionSpec;
                        in
                          {
                            inherit name;
                            version = b.elemAt versionMatch 0;
                          }
                      else
                        { inherit name version; }
                  )
                  dependency
              )
            );

      getSourceType = dependencyObject:
        if lib.hasInfix "@github:" dependencyObject.yarnName
            || (dependencyObject ? resolved
                && lib.hasInfix
                  "codeload.github.com/"
                  dependencyObject.resolved)
            || (lib.hasInfix "@git+" dependencyObject.yarnName) then
          if dependencyObject ? integrity then
            b.trace (
              "Warning: Using git despite integrity exists for"
              + "${getName dependencyObject}"
            )
              "git"
          else
            "git"
        else if lib.hasInfix "@link:" dependencyObject.yarnName
            || lib.hasInfix "@file:" dependencyObject.yarnName then
          "path"
        else
          "http";

      
      sourceConstructors = {
        git = dependencyObject:
          if utils.identifyGitUrl dependencyObject.resolved then
            (utils.parseGitUrl dependencyObject.resolved) // {
              version = dependencyObject.version;
            }
          else
            let
              githubUrlInfos = lib.splitString "/" dependencyObject.resolved;
              owner = lib.elemAt githubUrlInfos 3;
              repo = lib.elemAt githubUrlInfos 4;
              rev = lib.elemAt githubUrlInfos 6;
              version = dependencyObject.version;
            in
            {
              url = "https://github.com/${owner}/${repo}";
              inherit rev version;
            };

        path = dependencyObject:
          if lib.hasInfix "@link:" dependencyObject.yarnName then
            {
              version = dependencyObject.version;     
              path =
                lib.last (lib.splitString "@link:" dependencyObject.yarnName);
            }
          else if lib.hasInfix "@file:" dependencyObject.yarnName then
            {
              version = dependencyObject.version;     
              path =
              lib.last (lib.splitString "@file:" dependencyObject.yarnName);
            }
          else
            throw "unknown path format ${b.toJSON dependencyObject}";

        http = dependencyObject:
          {
            type = "http";
            version = dependencyObject.version;  
            hash =
              if dependencyObject ? integrity then
                dependencyObject.integrity
              else
                let
                  hash =
                    lib.last (lib.splitString "#" dependencyObject.resolved);
                in
                  if lib.stringLength hash == 40 then
                    hash
                  else
                    throw "Missing integrity for ${dependencyObject.yarnName}";
            url = lib.head (lib.splitString "#" dependencyObject.resolved);
          };
      };

      # TODO: implement createMissingSource
      # createMissingSource = name: version:
      #   let
      #     pname = lib.last (lib.splitString "/" name);
      #   in


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
  extraArgs = {

    name = {
      description = "The name of the main package";
      examples = [
        "react"
        "@babel/code-frame"
      ];
      default = "{automatic}";
      type = "argument";
    };

    noDev = {
      description = "Exclude development dependencies";
      type = "flag";
    };

    peer = {
      description = "Include peer dependencies";
      type = "flag";
    };

  };
}
