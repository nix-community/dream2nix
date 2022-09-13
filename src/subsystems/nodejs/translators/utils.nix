{
  lib,
  dlib,
}: let
  l = lib // builtins;
in rec {
  getMetaFromPackageJson = packageJson:
    {license = dlib.parseSpdxId (packageJson.license or "");}
    // (
      l.filterAttrs
      (n: v: l.any (on: n == on) ["description" "homepage"])
      packageJson
    );

  getPackageJsonDeps = packageJson: noDev:
    (packageJson.dependencies or {})
    // (lib.optionalAttrs (! noDev) (packageJson.devDependencies or {}));

  getWorkspaceLockFile = tree: project: fname: let
    # returns the parsed package-lock.json for a given project
    dirRelPath =
      if project ? subsystemInfo.workspaceParent
      then "${project.subsystemInfo.workspaceParent}"
      else "${project.relPath}";

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
    lib.mapAttrs'
    (wsRelPath: json:
      l.nameValuePair
      json.name
      json.version)
    (getWorkspacePackageJson tree workspaces);
}
