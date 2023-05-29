{
  lib,
  nodejsUtils,
  simpleTranslate,
  ...
}: let
  l = lib // builtins;

  getPackageLockPath = tree: workspaceParent: let
    parent = workspaceParent;
    node = tree.getNodeFromPath parent;
  in
    if node.files ? "npm-shrinkwrap.json"
    then "npm-shrinkwrap.json"
    else "package-lock.json";

  translate = {
    projectName,
    projectRelPath,
    workspaces ? [],
    workspaceParent ? projectRelPath,
    source,
    tree,
    # translator args
    noDev,
    nodejs,
    packageLock,
    packageJson,
    ...
  } @ args: let
    b = builtins;

    noDev = args.noDev;
    name = projectName;
    tree = args.tree.getNodeFromPath projectRelPath;
    relPath = projectRelPath;
    source = "${args.source}/${relPath}";

    packageVersion = packageJson.version or "unknown";

    packageLockDeps =
      if packageLock.lockfileVersion < 3
      then packageLock.dependencies or {}
      else
        throw ''
          package-lock.json files with version greater than 2 are not supported.
        '';

    rootDependencies = packageLockDeps;

    parsedDependencies = packageLockDeps;

    identifyGitSource = dependencyObject:
    # TODO: when integrity is there, and git url is github then use tarball instead
    # ! (dependencyObject ? integrity) &&
      nodejsUtils.identifyGitUrl dependencyObject.version;

    getVersion = dependencyObject: let
      # example: "version": "npm:@tailwindcss/postcss7-compat@2.2.4",
      npmMatch = b.match ''^npm:.*@(.*)$'' dependencyObject.version;
    in
      if npmMatch != null
      then b.elemAt npmMatch 0
      else if identifyGitSource dependencyObject
      then "0.0.0-rc.${b.substring 0 8 (nodejsUtils.parseGitUrl dependencyObject.version).rev}"
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
                  WARNING: could not find dependency ${name} in ${getPackageLockPath args.tree workspaceParent}
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
    simpleTranslate
    ({
      getDepByNameVer,
      dependenciesByOriginalID,
      ...
    }: rec {
      translatorName = name;
      location = relPath;

      # values
      inputData = pinnedRootDeps;

      defaultPackage = projectName;

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
          nodejsUtils.parseGitUrl dependencyObject.version;

        http = dependencyObject:
          if lib.hasPrefix "https://" dependencyObject.version
          then {
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
          else {
            url = dependencyObject.resolved;
            hash = dependencyObject.integrity;
          };

        path = dependencyObject:
        # in case of an entry with missing resolved field
          if ! lib.hasPrefix "file:" dependencyObject.version
          then {
            type = "path";
            path = let
              module = l.elemAt (l.splitString "/" dependencyObject.pname) 0;
            in "node_modules/${module}";
            rootName = projectName;
            rootVersion = packageVersion;
          }
          # in case of a "file:" entry
          else {
            type = "path";
            path = getPath dependencyObject;
            rootName = projectName;
            rootVersion = packageVersion;
          };
      };

      getDependencies = dependencyObject:
        dependencyObject.depsExact;
    });
in
  translate
