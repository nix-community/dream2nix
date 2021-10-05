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
      parsed = externals.npmlock2nix.readLockfile (builtins.elemAt inputFiles 0);

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
                  githubData = parseGithubDepedency pdata;
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
          {
            "${parsed.name}" =
              lib.mapAttrsToList
                (pname: pdata: "${pname}#${getVersion pdata}")
                (lib.filterAttrs
                  (pname: pdata: ! (pdata.dev or false) || dev)
                  parsed.dependencies);
          }
          //
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
      inputDirectories = [];
      inputFiles =
        lib.filter (f: builtins.match ".*(package-lock\\.json)" f != null) args.inputFiles;
    };

  specialArgs = {

    dev = {
      description = "include dependencies for development";
      type = "flag";
    };

  };
}
