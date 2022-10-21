{
  dlib,
  lib,
  utils,
  name,
  ...
}: let
  l = lib // builtins;
  nodejsUtils = import ../utils.nix {inherit dlib lib;};

  getPackageLockPath = tree: project: let
    parent = nodejsUtils.getWorkspaceParent project;
    node = tree.getNodeFromPath parent;
  in
    if node.files ? "npm-shrinkwrap.json"
    then "npm-shrinkwrap.json"
    else "package-lock.json";

  getPackageLock = tree: project:
    nodejsUtils.getWorkspaceLockFile tree project (getPackageLockPath tree project);

  translate = {
    project,
    source,
    tree,
    # translator args
    noDev,
    nodejs,
    ...
  } @ args: let
    b = builtins;

    noDev = args.noDev;
    name = project.name;
    tree = args.tree.getNodeFromPath project.relPath;
    relPath = project.relPath;
    source = "${args.source}/${relPath}";
    workspaces = project.subsystemInfo.workspaces or [];

    packageLock = (getPackageLock args.tree project).jsonContent or null;

    packageJson =
      (tree.getNodeFromPath "package.json").jsonContent;

    packageVersion = packageJson.version or "unknown";

    packageLockDeps =
      if packageLock == null
      then {}
      else packageLock.dependencies or {};

    rootDependencies = packageLockDeps;

    packageJsonDeps = nodejsUtils.getPackageJsonDeps packageJson noDev;

    parsedDependencies =
      l.filterAttrs
      (name: dep: packageJsonDeps ? "${name}")
      packageLockDeps;

    identifyGitSource = dependencyObject:
    # TODO: when integrity is there, and git url is github then use tarball instead
    # ! (dependencyObject ? integrity) &&
      dlib.identifyGitUrl dependencyObject.version;

    getVersion = dependencyObject: let
      # example: "version": "npm:@tailwindcss/postcss7-compat@2.2.4",
      npmMatch = b.match ''^npm:.*@(.*)$'' dependencyObject.version;
    in
      if npmMatch != null
      then b.elemAt npmMatch 0
      else if identifyGitSource dependencyObject
      then "0.0.0-rc.${b.substring 0 8 (dlib.parseGitUrl dependencyObject.version).rev}"
      else if lib.hasPrefix "file:" dependencyObject.version
      then let
        path = getPath dependencyObject;
      in
        if ! (l.pathExists "${source}/${path}/package.json")
        then
          throw ''
            The lock file references a sub-package residing at '${source}/${path}',
            but that directory doesn't exist or doesn't contain a package.json

            The reason might be that devDependencies are not included in this package release.
            Possible solutions:
              - get full package source via git and translate from there
              - disable devDependencies by passing `noDev` to the translator
          ''
        else
          (
            b.fromJSON
            (b.readFile "${source}/${path}/package.json")
          )
          .version
      else if lib.hasPrefix "https://" dependencyObject.version
      then "unknown"
      else dependencyObject.version;

    getPath = dependencyObject:
      lib.removePrefix "file:" dependencyObject.version;

    pinVersions = dependencies: parentScopeDeps:
      lib.mapAttrs
      (
        pname: pdata: let
          selfScopeDeps = parentScopeDeps // dependencies;
          requires = pdata.requires or {};
          dependencies = pdata.dependencies or {};

          # this was required to in order to fix .#resolveImpure for this projet:
          # https://gitlab.com/Shinobi-Systems/Shinobi/-/commit/a2faa40ab0e9952ff6a7fcf682534171614180c1
          filteredRequires =
            l.filterAttrs
            (name: spec:
              if selfScopeDeps ? ${name}
              then true
              else
                l.trace
                ''
                  WARNING: could not find dependency ${name} in ${getPackageLockPath args.tree project}
                  This might be expected for bundled dependencies of sub-dependencies.
                ''
                false)
            requires;
        in
          pdata
          // {
            depsExact =
              lib.forEach
              (lib.attrNames filteredRequires)
              (reqName: {
                name = reqName;
                version = getVersion selfScopeDeps."${reqName}";
              });
            dependencies = pinVersions dependencies selfScopeDeps;
          }
      )
      dependencies;

    pinnedRootDeps =
      pinVersions rootDependencies rootDependencies;

    createMissingSource = name: version: {
      type = "http";
      url = "https://registry.npmjs.org/${name}/-/${name}-${version}.tgz";
    };
  in
    utils.simpleTranslate
    ({
      getDepByNameVer,
      dependenciesByOriginalID,
      ...
    }: rec {
      translatorName = name;
      location = relPath;

      # values
      inputData = pinnedRootDeps;

      defaultPackage = project.name;

      packages =
        {"${defaultPackage}" = packageVersion;}
        // (nodejsUtils.getWorkspacePackages tree workspaces);

      mainPackageDependencies =
        lib.mapAttrsToList
        (pname: pdata: {
          name = pname;
          version = getVersion pdata;
        })
        (lib.filterAttrs
          (pname: pdata: ! (pdata.dev or false) || ! noDev)
          parsedDependencies);

      subsystemName = "nodejs";

      subsystemAttrs = {
        nodejsVersion = b.toString args.nodejs;
        meta = nodejsUtils.getMetaFromPackageJson packageJson;
      };

      # functions
      serializePackages = inputData: let
        serialize = inputData:
          lib.mapAttrsToList # returns list of lists
          
          (pname: pdata:
            [
              (pdata
                // {
                  inherit pname;
                  depsExact =
                    lib.filter
                    (req: (! (pdata.dependencies."${req.name}".bundled or false)))
                    pdata.depsExact or {};
                })
            ]
            ++ (lib.optionals (pdata ? dependencies)
              (lib.flatten
                (serialize
                  (lib.filterAttrs
                    (pname: data: ! data.bundled or false)
                    pdata.dependencies)))))
          inputData;
      in
        lib.filter
        (pdata:
          ! noDev || ! (pdata.dev or false))
        (lib.flatten (serialize inputData));

      getName = dependencyObject: dependencyObject.pname;

      inherit getVersion;

      getSourceType = dependencyObject:
        if identifyGitSource dependencyObject
        then "git"
        else if
          (lib.hasPrefix "file:" dependencyObject.version)
          || (
            (! lib.hasPrefix "https://" dependencyObject.version)
            && (! dependencyObject ? resolved)
          )
        then "path"
        else "http";

      sourceConstructors = {
        git = dependencyObject:
          dlib.parseGitUrl dependencyObject.version;

        http = dependencyObject:
          if lib.hasPrefix "https://" dependencyObject.version
          then rec {
            version = getVersion dependencyObject;
            url = dependencyObject.version;
            hash = dependencyObject.integrity;
          }
          else if dependencyObject.resolved == false
          then
            (createMissingSource
              (getName dependencyObject)
              (getVersion dependencyObject))
            // {
              hash = dependencyObject.integrity;
            }
          else rec {
            url = dependencyObject.resolved;
            hash = dependencyObject.integrity;
          };

        path = dependencyObject:
        # in case of an entry with missing resolved field
          if ! lib.hasPrefix "file:" dependencyObject.version
          then
            dlib.construct.pathSource {
              path = let
                module = l.elemAt (l.splitString "/" dependencyObject.pname) 0;
              in "node_modules/${module}";
              rootName = project.name;
              rootVersion = packageVersion;
            }
          # in case of a "file:" entry
          else
            dlib.construct.pathSource {
              path = getPath dependencyObject;
              rootName = project.name;
              rootVersion = packageVersion;
            };
      };

      getDependencies = dependencyObject:
        dependencyObject.depsExact;
    });
in rec {
  version = 2;

  type = "pure";

  inherit translate;

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
