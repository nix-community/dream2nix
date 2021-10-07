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

      dev,
      ...
    }:
    let
      packageLock =
        if inputDirectories != [] then
          "${lib.elemAt inputDirectories 0}/package-lock.json"
        else
          lib.elemAt inputFiles 0;

      parsed = externals.npmlock2nix.readLockfile packageLock;

      parseGithubDependency = dependency:
        externals.npmlock2nix.parseGitHubRef dependency.version;

      getVersion = dependency:
        if dependency ? from && dependency ? version then
          builtins.substring 0 8 (parseGithubDependency dependency).rev
        else
          dependency.version;

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
                    lib.forEach (lib.attrNames pdata.requires) (reqName:
                      "${reqName}#${getVersion selfScopeDeps."${reqName}"}"
                    );
                dependencies = pinVersions (pdata.dependencies or {}) selfScopeDeps;
              }
          )
          dependencies;
      
      packageLockWithPinnedVersions = pinVersions parsed.dependencies parsed.dependencies;

      # recursively collect dependencies
      parseDependencies = dependencies:
        lib.mapAttrsToList  # returns list of lists
          (pname: pdata:
            if ! dev && pdata.dev or false then
              []
            else
              # handle github dependency
              if pdata ? from && pdata ? version then
                let
                  githubData = parseGithubDependency pdata;
                in
                [ rec {
                  name = "${pname}#${version}";
                  version = builtins.substring 0 8 githubData.rev;
                  owner = githubData.org;
                  repo = githubData.repo;
                  rev = githubData.rev;
                  type = "github";
                  depsExact = pdata.depsExact;
                }]
              # handle http(s) dependency
              else 
                [rec {
                  name = "${pname}#${version}";
                  version = pdata.version;
                  url = pdata.resolved;
                  type = "fetchurl";
                  hash = pdata.integrity;
                  depsExact = pdata.depsExact;
                }]
            ++
            (lib.optionals (pdata ? dependencies)
              (lib.flatten (parseDependencies pdata.dependencies))
            )
          )
          dependencies;
    in

    # the dream lock
    rec {
      sources =
        let
          lockedSources = lib.listToAttrs (
            map
              (dep: lib.nameValuePair
                dep.name
                (
                  if dep.type == "github" then
                    { inherit (dep) type version owner repo rev; }
                  else
                    { inherit (dep) type version url hash; }
                )
              )
              (lib.flatten (parseDependencies packageLockWithPinnedVersions))
          );
        in
          # if only a package-lock.json is given, the main source is missing
          lockedSources // {
            "${parsed.name}" = {
              type = "unknown";
              version = parsed.version;
            };
          };

      generic = {
        buildSystem = "nodejs";
        producedBy = translatorName;
        mainPackage = parsed.name;
        dependencyGraph =
          lib.listToAttrs 
            (map
              (dep: lib.nameValuePair dep.name dep.depsExact)
              (lib.flatten (parseDependencies packageLockWithPinnedVersions))
            );
        sourcesCombinedHash = null;
      };

      buildSystem = {
        nodejsVersion = 14;
      };
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

  };
}
