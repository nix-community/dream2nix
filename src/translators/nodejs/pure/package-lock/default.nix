{
  lib,
  nodejs,

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

      noDev,
      nodejs,
      ...
    }@args:
    let

      b = builtins;

      dev = ! noDev;

      packageLock =
        if inputDirectories != [] then
          "${lib.elemAt inputDirectories 0}/package-lock.json"
        else
          lib.elemAt inputFiles 0;

      parsed = b.fromJSON (b.readFile packageLock);

      parsedDependencies = parsed.dependencies or {};

      identifyGitSource = dependencyObject:
        # TODO: when integrity is there, and git url is github then use tarball instead
        # ! (dependencyObject ? integrity) &&
          utils.identifyGitUrl dependencyObject.version;

      getVersion = dependencyObject:
        if identifyGitSource dependencyObject then
          "0.0.0-rc.${b.substring 0 8 (utils.parseGitUrl dependencyObject.version).rev}"
        else
          dependencyObject.version;
      
      pinVersions = dependencies: parentScopeDeps:
        lib.mapAttrs
          (pname: pdata:
            let
              selfScopeDeps = parentScopeDeps // dependencies;
              requires = pdata.requires or {};
              dependencies = pdata.dependencies or {};
            in
              pdata // {
                depsExact =
                  lib.forEach
                    (lib.attrNames requires)
                    (reqName: {
                      name = reqName;
                      version = getVersion selfScopeDeps."${reqName}";
                    });
                dependencies = pinVersions dependencies selfScopeDeps;
              }
          )
          dependencies;
      
      packageLockWithPinnedVersions = pinVersions parsedDependencies parsedDependencies;

    in

      utils.simpleTranslate translatorName {
        # values
        inputData = packageLockWithPinnedVersions;
        mainPackageName = parsed.name;
        mainPackageVersion = parsed.version;
        mainPackageDependencies =
          lib.mapAttrsToList
            (pname: pdata:
              { name = pname; version = getVersion pdata; })
            (lib.filterAttrs
              (pname: pdata: ! (pdata.dev or false) || dev)
              parsedDependencies);
        buildSystemName = "nodejs";
        buildSystemAttrs = { nodejsVersion = args.nodejs; };

        # functions
        serializePackages = inputData:
          let
            serialize = inputData:
              lib.mapAttrsToList  # returns list of lists
                (pname: pdata:
                  [ (pdata // { inherit pname; }) ]
                  ++
                  (lib.optionals (pdata ? dependencies)
                    (lib.flatten (serialize pdata.dependencies))))
                inputData;
          in
            lib.filter
              (pdata:
                dev || ! (pdata.dev or false))
              (lib.flatten (serialize inputData));

        getName = dependencyObject: dependencyObject.pname;

        inherit getVersion;

        getSourceType = dependencyObject:
          if identifyGitSource dependencyObject then
            "git"
          else
            "http";
        
        sourceConstructors = {

          git = dependencyObject:
            utils.parseGitUrl dependencyObject.version;

          http = dependencyObject:
            rec {
              version = dependencyObject.version;
              url = dependencyObject.resolved;
              hash = dependencyObject.integrity;
            };
        };

        getDependencies = dependencyObject: getDepByNameVer: dependenciesByOriginalID:
          dependencyObject.depsExact;
      };


  compatiblePaths =
    {
      inputDirectories,
      inputFiles,
    }@args:
    {
      inputDirectories = lib.filter 
        (utils.containsMatchingFile [ ''.*package-lock\.json'' ''.*package.json'' ])
        args.inputDirectories;

      inputFiles = [];
    };

  extraArgs = {

    noDev = {
      description = "Whether to exclude development dependencies";
      type = "flag";
    };

    nodejs = {
      description = "nodejs version to use for building";
      default = lib.elemAt (lib.splitString "." nodejs.version) 0;
      examples = [
        "14"
        "16"
      ];
      type = "argument";
    };

  };
}
