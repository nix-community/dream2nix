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
        (nodejsUtils.getWorkspaceLockFile tree project "package-lock.json").jsonContent;
      resolved = import ./v2-parse.nix {inherit lib lock source;};
    in
      resolved;

    resolved = getResolved args.tree project;

    packageVersion = resolved.self.version or "unknown";

    rootDependencies = resolved.self.deps;

    identifyGitSource = dep:
    # TODO: when integrity is there, and git url is github then use tarball instead
    # ! (dep ? integrity) &&
      dlib.identifyGitUrl dep.url;

    getVersion = dep: dep.version;

    getPath = dep:
      lib.removePrefix "file:" dep.url;

    getSource = {
      url,
      hash,
      ...
    }: {inherit url hash;};

    # TODO check that this works with workspaces
    extraInfo = b.foldl' (acc: dep:
      if dep.extra != {}
      then l.recursiveUpdate acc {${dep.pname}.${dep.version} = dep.extra;}
      else acc) {}
    resolved.allDeps;

    # TODO workspaces
    hasBuildScript = let
      pkgJson =
        (nodejsUtils.getWorkspaceLockFile tree project "package.json").jsonContent;
    in
      (pkgJson.scripts or {}) ? build;
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
      inputData = resolved.allDeps;

      defaultPackage = name;

      packages =
        {"${defaultPackage}" = packageVersion;}
        // (nodejsUtils.getWorkspacePackages tree workspaces);

      mainPackageDependencies = resolved.self.deps;

      subsystemName = "nodejs";

      subsystemAttrs = {
        inherit extraInfo hasBuildScript;
        nodejsVersion = args.nodejs;
      };

      # functions
      serializePackages = inputData: inputData;

      getName = dep: dep.pname;

      inherit getVersion;

      # TODO handle npm link maybe? not sure what it looks like in lock
      getSourceType = dep:
        if lib.hasPrefix "file:" dep.url
        then "path"
        else if identifyGitSource dep
        then "git"
        else "http";

      sourceConstructors = {
        git = dep:
          (getSource dep)
          // (dlib.parseGitUrl dep.url);

        http = dep: (getSource dep);

        path = dep: (dlib.construct.pathSource {
          path = getPath dep;
          rootName = project.name;
          rootVersion = packageVersion;
        });
      };

      getDependencies = dep: dep.deps;
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

    transitiveBinaries = {
      description = "Should all the binaries from all modules be available, or only those from dependencies";
      default = false;
      type = "boolean";
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
