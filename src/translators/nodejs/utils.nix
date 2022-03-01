{
  lib,
}: let

l = lib // builtins;

in rec {

  # One translator call can process a whole workspace containing all
  # sub-packages of that workspace.
  # Therefore we can filter out projects which are children of a workspace.
  filterProjects = projects:
    let
      workspaceRoots =
        l.filter
          (proj: proj.subsystemInfo.workspaces or [] != [])
          projects;

      allWorkspaceChildren =
        l.flatten
          (l.map
            (root: root.subsystemInfo.workspaces)
            workspaceRoots);

      childrenRemoved =
        l.filter
          (proj:
            (! l.elem proj.relPath allWorkspaceChildren))
          projects;

    in
      childrenRemoved;

  getPackageJsonDeps = packageJson: noDev:
    packageJson.dependencies or {}
    // (lib.optionalAttrs (! noDev) (packageJson.devDependencies or {}));

  getWorkspaceLockFile = tree: project: fname: let
    # returns the parsed package-lock.json for a given project
    dirRelPath =
      if project ? subsystemInfo.workspaceParent then
        "${project.subsystemInfo.workspaceParent}"
      else
        "${project.relPath}";

    packageJson =
      (tree.getNodeFromPath "${dirRelPath}/package.json").jsonContent;

    hasNoDependencies =
      ! packageJson ? dependencies && ! packageJson ? devDependencies;

  in
    if hasNoDependencies then
      null
    else
      tree.getNodeFromPath "${dirRelPath}/${fname}";


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
