{
  dlib,
  lib,
}: let
  l = lib // builtins;
  nodejsUtils = import ../../utils.nix {inherit lib;};
  parser = import ./parser.nix {inherit lib;};

  getYarnLock = tree: proj:
    tree.getNodeFromPath "${proj.relPath}/yarn.lock";

  translate = {
    translatorName,
    utils,
    ...
  }: {
    project,
    source,
    tree,
    # extraArgs
    nodejs,
    noDev,
    ...
  } @ args: let
    b = builtins;
    dev = ! noDev;
    name = project.name;
    relPath = project.relPath;
    tree = args.tree.getNodeFromPath project.relPath;
    workspaces = project.subsystemInfo.workspaces or [];
    yarnLock = parser.parse (tree.getNodeFromPath "yarn.lock").content;

    defaultPackage =
      if name != "{automatic}"
      then name
      else
        packageJson.name
        or (throw (
          "Could not identify package name. "
          + "Please specify extra argument 'name'"
        ));

    packageJson =
      (tree.getNodeFromPath "package.json").jsonContent;

    packageJsonDeps = nodejsUtils.getPackageJsonDeps packageJson noDev;

    workspacesPackageJson = nodejsUtils.getWorkspacePackageJson tree workspaces;
  in
    utils.simpleTranslate2
    ({objectsByKey, ...}: let
      makeWorkspaceExtraObject = workspace: let
        json = workspacesPackageJson."${workspace}";
        name = json.name or workspace;
        version = json.version or "unknown";
      in {
        inherit name version;

        dependencies =
          l.mapAttrsToList
          (depName: semVer: let
            yarnName = "${depName}@${semVer}";
            depObject = objectsByKey.yarnName."${yarnName}";
          in
            if exportedWorkspacePackages ? "${depName}"
            then {
              name = depName;
              version = exportedWorkspacePackages."${depName}";
            }
            else {
              name = depName;
              version = depObject.version;
            })
          (nodejsUtils.getPackageJsonDeps json noDev);

        sourceSpec = {
          type = "path";
          path = workspace;
          rootName = defaultPackage;
          rootVersion = packageJson.version or "unknown";
        };
      };

      extraObjects = l.map makeWorkspaceExtraObject workspaces;

      exportedWorkspacePackages =
        l.listToAttrs
        (l.map
          (wsObject:
            l.nameValuePair
            wsObject.name
            wsObject.version)
          extraObjects);

      getSourceType = rawObj: finalObj: let
        dObj = rawObj;
      in
        if
          lib.hasInfix "@github:" dObj.yarnName
          || (dObj
            ? resolved
            && lib.hasInfix "codeload.github.com/" dObj.resolved)
          || lib.hasInfix "@git+" dObj.yarnName
          # example:
          # "jest-image-snapshot@https://github.com/machard/jest-image-snapshot#machard-patch-1":
          #   version "4.2.0"
          #   resolved "https://github.com/machard/jest-image-snapshot#d087e8683859dba2964b5866a4d1eb02ba64e7b9"
          || (lib.hasInfix "@https://github.com" dObj.yarnName
            && lib.hasPrefix "https://github.com" dObj.resolved)
        then
          if dObj ? integrity
          then
            b.trace (
              "Warning: Using git despite integrity exists for"
              + "${finalObj.name}"
            )
            "git"
          else "git"
        else if
          lib.hasInfix "@link:" dObj.yarnName
          || lib.hasInfix "@file:" dObj.yarnName
        then "path"
        else "http";
    in rec {
      inherit defaultPackage extraObjects translatorName;

      exportedPackages =
        {"${defaultPackage}" = packageJson.version or "unknown";}
        // exportedWorkspacePackages;

      subsystemName = "nodejs";

      subsystemAttrs = {nodejsVersion = args.nodejs;};

      keys = {
        yarnName = rawObj: finalObj:
          rawObj.yarnName;
      };

      extractors = {
        name = rawObj: finalObj:
          if lib.hasInfix "@git+" rawObj.yarnName
          then lib.head (lib.splitString "@git+" rawObj.yarnName)
          # Example:
          # @matrix-org/olm@https://gitlab.matrix.org/api/v4/projects/27/packages/npm/@matrix-org/olm/-/@matrix-org/olm-3.2.3.tgz
          else if lib.hasInfix "@https://" rawObj.yarnName
          then lib.head (lib.splitString "@https://" rawObj.yarnName)
          else let
            split = lib.splitString "@" rawObj.yarnName;
            version = lib.last split;
          in
            if lib.hasPrefix "@" rawObj.yarnName
            then lib.removeSuffix "@${version}" rawObj.yarnName
            else lib.head split;

        version = rawObj: finalObj:
          if l.hasInfix "@git+" rawObj.yarnName
          then let
            split = l.splitString "@git+" rawObj.yarnName;
            gitUrl = l.last split;
          in
            # l.strings.sanitizeDerivationName
            "${rawObj.version}@git+${gitUrl}"
          else rawObj.version;

        dependencies = rawObj: finalObj: let
          dependencies = let
            deps =
              rawObj.dependencies
              or {}
              // rawObj.optionalDependencies or {};
          in
            lib.mapAttrsToList
            (name: version: {"${name}" = version;})
            deps;
        in
          lib.forEach
          dependencies
          (
            dependency:
              builtins.head (
                lib.mapAttrsToList
                (
                  name: versionSpec: let
                    yarnName = "${name}@${versionSpec}";
                    depObject = objectsByKey.yarnName."${yarnName}";
                    version = depObject.version;
                  in
                    if ! objectsByKey.yarnName ? ${yarnName}
                    then
                      # handle missing lock file entry
                      let
                        versionMatch =
                          b.match ''.*\^([[:digit:]|\.]+)'' versionSpec;
                      in {
                        inherit name;
                        version = b.elemAt versionMatch 0;
                      }
                    else {inherit name version;}
                )
                dependency
              )
          );

        sourceSpec = rawObj: finalObj: let
          type = getSourceType rawObj finalObj;
        in
          {inherit type;}
          // (
            if type == "git"
            then
              if utils.identifyGitUrl rawObj.resolved
              then
                (utils.parseGitUrl rawObj.resolved)
                // {
                  version = rawObj.version;
                }
              else let
                githubUrlInfos = lib.splitString "/" rawObj.resolved;
                owner = lib.elemAt githubUrlInfos 3;
                repo = lib.elemAt githubUrlInfos 4;
              in
                if b.length githubUrlInfos == 7
                then let
                  rev = lib.elemAt githubUrlInfos 6;
                in {
                  url = "https://github.com/${owner}/${repo}";
                  inherit rev;
                }
                else if b.length githubUrlInfos == 5
                then let
                  urlAndRev = lib.splitString "#" rawObj.resolved;
                in {
                  url = lib.head urlAndRev;
                  rev = lib.last urlAndRev;
                }
                else
                  throw (
                    "Unable to parse git dependency for: "
                    + "${finalObj.name}#${finalObj.version}"
                  )
            else if type == "path"
            then
              if lib.hasInfix "@link:" rawObj.yarnName
              then {
                path =
                  lib.last (lib.splitString "@link:" rawObj.yarnName);
              }
              else if lib.hasInfix "@file:" rawObj.yarnName
              then {
                path =
                  lib.last (lib.splitString "@file:" rawObj.yarnName);
              }
              else throw "unknown path format ${b.toJSON rawObj}"
            else # type == "http"
              {
                type = "http";
                hash =
                  if rawObj ? integrity
                  then rawObj.integrity
                  else let
                    hash =
                      lib.last (lib.splitString "#" rawObj.resolved);
                  in
                    if lib.stringLength hash == 40
                    then hash
                    else throw "Missing integrity for ${rawObj.yarnName}";
                url = lib.head (lib.splitString "#" rawObj.resolved);
              }
          );
      };

      extraDependencies =
        l.mapAttrsToList
        (name: semVer: let
          depYarnKey = "${name}@${semVer}";
          dependencyAttrs =
            if ! yarnLock ? "${depYarnKey}"
            then throw "Cannot find entry for top level dependency: '${depYarnKey}'"
            else yarnLock."${depYarnKey}";
        in {
          name = defaultPackage;
          version = packageJson.version or "unknown";
          dependencies = [
            {
              inherit name;
              version = dependencyAttrs.version;
            }
          ];
        })
        packageJsonDeps;

      serializedRawObjects =
        lib.mapAttrsToList
        (yarnName: depAttrs: depAttrs // {inherit yarnName;})
        yarnLock;
    });
in {
  version = 2;

  inherit translate;

  # inherit projectName function from package-lock translator
  projectName = dlib.translators.translators.nodejs.pure.package-lock.projectName;

  # This allows the framework to detect if the translator is compatible with the given input
  # to automatically select the right translator.
  compatible = {source}:
    dlib.containsMatchingFile [''.*yarn\.lock'' ''.*package.json''] source;

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
