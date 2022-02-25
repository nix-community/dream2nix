{
  dlib,
  lib,
}:

let
  b = builtins;
  l = lib // builtins;
in

rec {
  translate =
    {
      translatorName,
      utils,
      ...
    }:
    {
      source,

      name,
      noDev,
      nodejs,
      ...
    }@args:
    let

      b = builtins;

      dev = ! noDev;

      inputDir = source;

      packageLock = "${inputDir}/package-lock.json";

      parsed = b.fromJSON (b.readFile packageLock);

      parsedDependencies = parsed.dependencies or {};

      identifyGitSource = dependencyObject:
        # TODO: when integrity is there, and git url is github then use tarball instead
        # ! (dependencyObject ? integrity) &&
          utils.identifyGitUrl dependencyObject.version;

      getVersion = dependencyObject:
        let
          # example: "version": "npm:@tailwindcss/postcss7-compat@2.2.4",
          npmMatch = b.match ''^npm:.*@(.*)$'' dependencyObject.version;

        in
          if npmMatch != null then
            b.elemAt npmMatch 0
          else if identifyGitSource dependencyObject then
            "0.0.0-rc.${b.substring 0 8 (utils.parseGitUrl dependencyObject.version).rev}"
          else if lib.hasPrefix "file:" dependencyObject.version then
            let
              path = getPath dependencyObject;
            in
              (b.fromJSON
                (b.readFile "${inputDir}/${path}/package.json")
              ).version
          else if lib.hasPrefix "https://" dependencyObject.version then
            "unknown"
          else
            dependencyObject.version;

      getPath = dependencyObject:
        lib.removePrefix "file:" dependencyObject.version;

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

      createMissingSource = name: version:
        {
          type = "http";
          url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
        };

    in

      utils.simpleTranslate
        ({
          getDepByNameVer,
          dependenciesByOriginalID,
          ...
        }:

        rec {

        inherit translatorName;

        # values
        inputData = packageLockWithPinnedVersions;

        defaultPackage =
          if name != "{automatic}" then
            name
          else
            parsed.name or (throw (
              "Could not identify package name. "
              + "Please specify extra argument 'name'"
            ));

        packages."${defaultPackage}" = parsed.version or "unknown";

        mainPackageDependencies =
          lib.mapAttrsToList
            (pname: pdata:
              { name = pname; version = getVersion pdata; })
            (lib.filterAttrs
              (pname: pdata: ! (pdata.dev or false) || dev)
              parsedDependencies);

        subsystemName = "nodejs";

        subsystemAttrs = { nodejsVersion = args.nodejs; };

        # functions
        serializePackages = inputData:
          let
            serialize = inputData:
              lib.mapAttrsToList  # returns list of lists
                (pname: pdata:
                  [ (pdata // {
                      inherit pname;
                      depsExact =
                        lib.filter
                          (req:
                            (! (pdata.dependencies."${req.name}".bundled or false)))
                          pdata.depsExact or {};
                    }) ]
                  ++
                  (lib.optionals (pdata ? dependencies)
                    (lib.flatten
                      (serialize
                        (lib.filterAttrs
                          (pname: data: ! data.bundled or false)
                          pdata.dependencies)))))
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
          else if lib.hasPrefix "file:" dependencyObject.version then
            "path"
          else
            "http";

        sourceConstructors = {

          git = dependencyObject:
            utils.parseGitUrl dependencyObject.version;

          http = dependencyObject:
            if lib.hasPrefix "https://" dependencyObject.version then
              rec {
                version = getVersion dependencyObject;
                url = dependencyObject.version;
                hash = dependencyObject.integrity;
              }
            else if dependencyObject.resolved == false then
              (createMissingSource
                (getName dependencyObject)
                (getVersion dependencyObject))
              // {
                hash = dependencyObject.integrity;
              }
            else
              rec {
                url = dependencyObject.resolved;
                hash = dependencyObject.integrity;
              };

          path = dependencyObject:
            rec {
              path = getPath dependencyObject;
            };
        };

        getDependencies = dependencyObject:
          dependencyObject.depsExact;
      });


  projectName =
    {
      source,
    }:
    let
      packageJson = "${source}/package.json";
      parsed = b.fromJSON (b.readFile packageJson);
    in
      if b.pathExists packageJson && parsed ? name then
        parsed.name
      else
        null;


  compatible =
    {
      source,
    }:
    dlib.containsMatchingFile
      [
        ''.*package-lock\.json''
        ''.*package.json''
      ]
      source;

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

    # TODO: this should either be removed or only used to select
    # the nodejs version for translating, not for building.
    nodejs = {
      description = "nodejs version to use for building";
      default = "14";
      examples = [
        "14"
        "16"
      ];
      type = "argument";
    };

  };
}
