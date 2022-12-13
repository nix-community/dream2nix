{
  dlib,
  lib,
  ...
}: let
  l = lib // builtins;

  discover = {tree}: let
    projects = discoverInternal {
      inherit tree;
    };
  in
    projects;

  getTranslatorNames = tree: let
    packageJson = tree.files."package.json".jsonContent;
    translators =
      # if the package has no dependencies we use the
      # package-lock translator with `packageLock = null`
      if
        (packageJson.dependencies or {} == {})
        && (packageJson.devDependencies or {} == {})
        && (packageJson.workspaces or [] == [])
      then ["package-lock"]
      else
        l.optionals (tree.files ? "npm-shrinkwrap.json" || tree.files ? "package-lock.json") ["package-lock"]
        ++ l.optionals (tree.files ? "yarn.lock") ["yarn-lock"]
        ++ ["package-json"];
  in
    translators;

  # returns all relative paths to workspaces defined by a glob
  getWorkspacePaths = glob: tree: let
    paths =
      if l.hasSuffix "*" glob
      then let
        prefix = l.removeSuffix "*" glob;
        path = "${tree.fullPath}/${prefix}";

        dirNames =
          if l.pathExists path
          then dlib.listDirs path
          else
            l.trace
            "WARNING: Detected workspace ${glob} does not exist."
            [];

        existingWsPaths =
          l.filter
          (wsPath:
            if l.pathExists "${path}/${wsPath}/package.json"
            then true
            else let
              notExistingPath =
                dlib.sanitizeRelativePath "${prefix}/${wsPath}";
            in
              l.trace
              "WARNING: Detected workspace ${notExistingPath} does not exist."
              false)
          dirNames;
      in
        l.map (dname: "${prefix}/${dname}") existingWsPaths
      else if l.pathExists "${tree.fullPath}/${glob}/package.json"
      then [glob]
      else
        l.trace
        "WARNING: Detected workspace ${glob} does not exist."
        [];
  in
    map dlib.sanitizeRelativePath paths;

  # collect project info for workspaces defined by current package.json
  getWorkspaceRelPaths = tree: parentInfo: let
    packageJson = tree.files."package.json".jsonContent;
    workspacesRaw = packageJson.workspaces or [];

    workspacesFlattened =
      if l.isAttrs workspacesRaw
      then
        l.flatten
        (l.mapAttrsToList
          (category: workspaces: workspaces)
          workspacesRaw)
      else if l.isList workspacesRaw
      then workspacesRaw
      else throw "Error parsing workspaces in ${tree.files."package.json".relPath}";
  in
    l.flatten
    (l.forEach workspacesFlattened
      (glob: getWorkspacePaths glob tree));

  discoverInternal = {
    tree,
    # Internal parameter preventing workspace projects from being discovered
    # twice.
    alreadyDiscovered ? {},
  }: let
    foundSubProjects = alreadyDiscovered:
      l.flatten
      (l.mapAttrsToList
        (dname: dir:
          discoverInternal {
            inherit alreadyDiscovered;
            tree = dir;
          })
        (tree.directories or {}));
  in
    # skip if not a nodajs project
    if
      alreadyDiscovered
      ? "${tree.relPath}"
      || ! tree ? files."package.json"
    then
      # this will be cleaned by `flatten` for sub-directories
      foundSubProjects alreadyDiscovered
    else let
      # project info of current directory
      currentProjectInfo = dlib.construct.discoveredProject {
        inherit (tree) relPath;
        name = tree.files."package.json".jsonContent.name or tree.relPath;
        subsystem = "nodejs";
        translators = getTranslatorNames tree;
        subsystemInfo = l.optionalAttrs (workspaceRelPaths != []) {
          workspaces =
            l.map
            (w: l.removePrefix "${tree.relPath}/" w)
            workspaceRelPaths;
        };
      };

      workspaceRelPaths = getWorkspaceRelPaths tree currentProjectInfo;

      excludePaths =
        l.map
        (childRelPath:
          dlib.sanitizeRelativePath
          (currentProjectInfo.relPath + "/" + childRelPath))
        workspaceRelPaths;

      # contains all workspace children
      excludes =
        l.genAttrs
        excludePaths
        (_: null);

      # index of already found projects
      # This is needed, because sub-projects also contain a `package.json`,
      # and would otherwise be discovered again as an independent project.
      alreadyDiscovered' =
        alreadyDiscovered
        // excludes
        // {
          ${currentProjectInfo.relPath} = null;
        };
    in
      # the current directory
      [currentProjectInfo]
      # sub-directories
      # Thanks to `alreadyDiscovered`, workspace projects won't be discovered
      # a second time.
      ++ (foundSubProjects alreadyDiscovered');
in {
  inherit discover;
}
