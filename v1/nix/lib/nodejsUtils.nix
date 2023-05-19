{
  lib,
  parseSpdxId,
}: let
  l = lib // builtins;
in rec {
  getMetaFromPackageJson = packageJson:
    {license = parseSpdxId (packageJson.license or "");}
    // (
      l.filterAttrs
      (n: v: l.any (on: n == on) ["description" "homepage"])
      packageJson
    );

  getPackageJsonDeps = packageJson: noDev:
    (packageJson.dependencies or {})
    // (lib.optionalAttrs (! noDev) (packageJson.devDependencies or {}));

  getWorkspaceLockFile = tree: workspaceParent: fname: let
    # returns the parsed package-lock.json for a given project
    dirRelPath = workspaceParent;

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

  identifyGitUrl = url:
    l.hasPrefix "git+" url
    || l.match ''^github:.*/.*#.*'' url != null;

  parseGitUrl = url: let
    githubMatch = l.match ''^github:(.*)/(.*)#(.*)$'' url;
  in
    if githubMatch != null
    then let
      owner = l.elemAt githubMatch 0;
      repo = l.elemAt githubMatch 1;
      rev = l.elemAt githubMatch 2;
    in {
      url = "https://github.com/${owner}/${repo}";
      inherit rev;
    }
    else let
      splitUrlRev = l.splitString "#" url;
      rev = l.last splitUrlRev;
      urlOnly = l.head splitUrlRev;
    in
      if l.hasPrefix "git+ssh://" urlOnly
      then {
        inherit rev;
        url = "https://${(l.last (l.splitString "@" url))}";
      }
      else if l.hasPrefix "git+https://" urlOnly
      then {
        inherit rev;
        url = l.removePrefix "git+" urlOnly;
      }
      else throw "Cannot parse git url: ${url}";
}
