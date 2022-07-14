# TODO use translate2
# TODO use package.json for v1 lock files
{
  dlib,
  lib,
  ...
}: let
  b = builtins;
  l = lib // builtins;
  nodejsUtils = import ../utils.nix {inherit lib;};

  translate = {
    translatorName,
    utils,
    pkgs,
    ...
  }: {
    project,
    source,
    tree,
    # translator args
    # name
    # nodejs
    ...
  } @ args: let
    b = builtins;

    name =
      if (args.name or "{automatic}") != "{automatic}"
      then args.name
      else project.name;
    tree = args.tree.getNodeFromPath project.relPath;
    relPath = project.relPath;
    source = "${args.source}/${relPath}";
    workspaces = project.subsystemInfo.workspaces or [];

    getResolved = tree: project: let
      lock =
        nodejsUtils.getWorkspaceLockFile tree project "package-lock.json";
      resolved = pkgs.runCommandLocal "resolved.json" {} ''
        ${pkgs.nodejs}/bin/node ${./resolver.cjs} ${lock.fullPath} $out
      '';
    in
      l.fromJSON (l.readFile resolved);

    lock = getResolved args.tree project;

    packageVersion = lock.version or "unknown";

    rootDependencies = lock.self.deps;

    identifyGitSource = dependencyObject:
    # TODO: when integrity is there, and git url is github then use tarball instead
    # ! (dependencyObject ? integrity) &&
      dlib.identifyGitUrl dependencyObject.url;

    getVersion = dependencyObject: dependencyObject.version;

    getPath = dependencyObject:
      lib.removePrefix "file:" dependencyObject.url;

    stripDep = dep: l.removeAttrs dep ["pname" "version" "deps"];
  in
    utils.simpleTranslate
    ({
      getDepByNameVer,
      dependenciesByOriginalID,
      ...
    }: rec {
      inherit translatorName;
      location = relPath;

      # values
      inputData = lock.allDeps;

      defaultPackage = name;

      packages =
        {"${defaultPackage}" = packageVersion;}
        // (nodejsUtils.getWorkspacePackages tree workspaces);

      # Also add devDeps for devShell
      mainPackageDependencies = lock.self.deps;

      subsystemName = "nodejs";

      subsystemAttrs = {nodejsVersion = args.nodejs;};

      # functions
      serializePackages = inputData: inputData;

      getName = dependencyObject: dependencyObject.pname;

      inherit getVersion;

      # TODO handle link maybe?
      # TODO handle inBundle?
      getSourceType = dependencyObject:
        if identifyGitSource dependencyObject
        then "git"
        else if lib.hasPrefix "file:" dependencyObject.url
        then "path"
        else "http";

      sourceConstructors = {
        git = dependencyObject:
          (stripDep dependencyObject)
          // (dlib.parseGitUrl dependencyObject.url);

        http = dependencyObject: (stripDep dependencyObject);

        path = dependencyObject:
          (stripDep dependencyObject)
          // (dlib.construct.pathSource {
            path = getPath dependencyObject;
            rootName = project.name;
            rootVersion = packageVersion;
          });
      };

      getDependencies = dependencyObject: dependencyObject.deps;
    });
in rec {
  version = 2;

  type = "ifd";

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

    # TODO: this should either be removed or only used to select
    # the nodejs version for translating, not for building.
    nodejs = {
      description = "nodejs version to use for building";
      default = "16";
      examples = [
        "14"
        "16"
      ];
      type = "argument";
    };
  };
}
