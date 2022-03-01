{
  dlib,
  lib,

  subsystem,
}:

let
  l = lib // builtins;

  discover =
    {
      tree,
    }:
    discoverInternal {
      inherit tree;
    };


  getTranslatorNames = path:
    let
      nodes = l.readDir path;
      packageJson = l.fromJSON (l.readFile "${path}/package.json");
    in
      # if the package has no dependencies we use the
      # package-lock translator with `packageLock = null`
      if ! packageJson ? dependencies && ! packageJson ? devDependencies
      then [ "package-lock" ]

      else
        l.optionals (nodes ? "package-lock.json") [ "package-lock" ]
        ++ l.optionals (nodes ? "yarn.lock") [ "yarn-lock" ]
        ++ [ "package-json" ];

  # returns the parsed package.json of a given directory
  getPackageJson = dirPath:
    l.fromJSON (l.readFile "${dirPath}/package.json");

  # returns all relative paths to workspaces defined by a glob
  getWorkspacePaths = glob: tree:
    if l.hasSuffix "*" glob then
      let
        prefix = l.removeSuffix "*" glob;
        dirNames = dlib.listDirs "${tree.fullPath}/${prefix}";
      in
        l.map (dname: "${prefix}/${dname}") dirNames
    else
      [ glob ];

  # collect project info for workspaces defined by current package.json
  getWorkspaces = tree: parentInfo:
    let
      packageJson = tree.files."package.json".jsonContent;
    in
      l.flatten
        (l.forEach (packageJson.workspaces or [])
          (glob:
            let
              workspacePaths = getWorkspacePaths glob tree;
            in
              l.forEach workspacePaths
                (wPath: makeWorkspaceProjectInfo tree wPath parentInfo)));

  makeWorkspaceProjectInfo = tree: wsRelPath: parentInfo:
    {
      inherit subsystem;
      name =
        (getPackageJson "${tree.fullPath}/${wsRelPath}").name
        or "${parentInfo.name}/${wsRelPath}";
      relPath = dlib.sanitizeRelativePath "${tree.relPath}/${wsRelPath}";
      translators =
        l.unique
          (parentInfo.translators
          ++ (getTranslatorNames "${tree.fullPath}/${wsRelPath}"));
      subsystemInfo = {
        workspaceParent = tree.relPath;
      };
    };

  discoverInternal =
    {
      tree,

      # Internal parameter preventing workspace projects from being discovered
      # twice.
      alreadyDiscovered ? {},
    }:
    let
      foundSubProjects = alreadyDiscovered:
        l.flatten
          ((l.mapAttrsToList
            (dname: dir: discoverInternal {
              inherit alreadyDiscovered;
              tree = dir;
            })
            (tree.directories or {})));
    in
    # skip if not a nodajs project
    if alreadyDiscovered ? "${tree.relPath}"
        || ! tree ? files."package.json" then
      # this will be cleaned by `flatten` for sub-directories
      foundSubProjects alreadyDiscovered
    else
      let

        # project info of current directory
        currentProjectInfo =
          {
            inherit subsystem;
            inherit (tree) relPath;
            name = tree.files."package.json".jsonContent.name or tree.relPath;
            translators = getTranslatorNames tree.fullPath;
            subsystemInfo =
              l.optionalAttrs (workspaces != []) {
                workspaces = l.map (w: w.relPath) workspaces;
              };
          };

        workspaces = getWorkspaces tree currentProjectInfo;


        # list of all projects infos found by the current iteration
        foundProjects =
          # current directories project info
          [ currentProjectInfo ]

          # workspaces defined by the current directory
          ++
          workspaces;

        # index of already found projects
        # This is needed, because sub-projects also contain a `package.json`,
        # and would otherwise be discovered again as an independent project.
        alreadyDiscovered' =
          alreadyDiscovered
          //
          (l.genAttrs
            (l.map (p: p.relPath) foundProjects)
            (relPath: null));
      in
        # l.trace tree.directories
        # the current directory
        foundProjects

        # sub-directories
        # Thanks to `alreadyDiscovered`, workspace projects won't be discovered
        # a second time.
        ++
        (foundSubProjects alreadyDiscovered');
in

{
  inherit discover;
}
