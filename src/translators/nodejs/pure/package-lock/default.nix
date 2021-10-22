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

      dev,
      nodejs,
      ...
    }@args:
    let

      b = builtins;

      packageLock =
        if inputDirectories != [] then
          "${lib.elemAt inputDirectories 0}/package-lock.json"
        else
          lib.elemAt inputFiles 0;

      parsed = b.fromJSON (b.readFile packageLock);

      identifyGitSource = dependencyObject:
        # TODO: when integrity is there, and git url is github then use tarball instead
        # ! (dependencyObject ? integrity) &&
          utils.identifyGitUrl dependencyObject.version;

      getVersion = dependencyObject:
        if identifyGitSource dependencyObject then
          builtins.substring 0 8 (utils.parseGitUrl dependencyObject.version).rev
        else
          dependencyObject.version;
      
      pinVersions = dependencies: parentScopeDeps:
        lib.mapAttrs
          (pname: pdata:
            let
              selfScopeDeps = parentScopeDeps // (pdata.dependencies or {});
            in
              pdata // {
                depsExact =
                  if ! pdata ? requires then
                    []
                  else
                    lib.forEach (lib.attrNames pdata.requires) (reqName: {
                      name = reqName;
                      version = getVersion selfScopeDeps."${reqName}";
                    });
                dependencies = pinVersions (pdata.dependencies or {}) selfScopeDeps;
              }
          )
          dependencies;
      
      packageLockWithPinnedVersions = pinVersions parsed.dependencies parsed.dependencies;

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
              parsed.dependencies);
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
            "fetchurl";
        
        sourceConstructors = {

          git = dependencyObject:
            utils.parseGitUrl dependencyObject.version;

          fetchurl = dependencyObject:
            rec {
              version = dependencyObject.version;
              url = dependencyObject.resolved;
              hash = dependencyObject.integrity;
            };
        };

        getDependencies = dependencyObject: getDepByNameVer: getDepByOriginalID:
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

  specialArgs = {

    dev = {
      description = "include dependencies for development";
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
