{config, ...}: let
  l = config.lib // builtins;
  dlib = config.dlib;
  getMetaFromPackageJson = packageJson:
    {license = dlib.parseSpdxId (packageJson.license or "");}
    // (
      l.filterAttrs
      (n: v: l.any (on: n == on) ["description" "homepage"])
      packageJson
    );

  getPackageJsonDeps = packageJson: noDev:
    (packageJson.dependencies or {})
    // (l.optionalAttrs (! noDev) (packageJson.devDependencies or {}));

  getWorkspaceParent = project:
    if project ? subsystemInfo.workspaceParent
    then "${project.subsystemInfo.workspaceParent}"
    else "${project.relPath}";

  getWorkspaceLockFile = tree: project: fname: let
    # returns the parsed package-lock.json for a given project
    dirRelPath = getWorkspaceParent project;

    packageJson =
      (tree.getNodeFromPath "${dirRelPath}/package.json").jsonContent;

    hasNoDependencies =
      ((packageJson.dependencies or {}) == {})
      && ((packageJson.devDependencies or {}) == {})
      && (! packageJson ? workspaces);
  in
    if hasNoDependencies
    then null
    else tree.getNodeFromPath "${dirRelPath}/${fname}";

  getWorkspacePackageJson = tree: workspaces:
    l.genAttrs
    workspaces
    (wsRelPath:
      (tree.getNodeFromPath "${wsRelPath}/package.json").jsonContent);

  getWorkspacePackages = tree: workspaces:
    l.mapAttrs'
    (wsRelPath: json:
      l.nameValuePair
      json.name
      json.version)
    (getWorkspacePackageJson tree workspaces);
in {
  config.functions.translators.nodejs = {
    inherit
      getMetaFromPackageJson
      getPackageJsonDeps
      getWorkspaceLockFile
      getWorkspacePackageJson
      getWorkspacePackages
      getWorkspaceParent
      ;
  };
}
