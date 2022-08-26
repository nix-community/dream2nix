# This parses a v2 package-lock.json file. This format includes all information
# to get correct dependencies, including peer dependencies and multiple
# versions. lock.packages is a set that includes the path of each dep, and
# this function teases it apart to know exactly which dep is being resolved.
# The format of the lockfile is documented at
#   https://docs.npmjs.com/cli/v8/configuring-npm/package-lock-json/
{
  lib,
  lock,
  source,
}:
assert (lib.elem lock.lockfileVersion [2 3]); let
  b = builtins;
  # { "node_modules/@foo/bar/node_modules/meep": pkg; ... }
  pkgs = lock.packages;
  lockName = lock.name or "unnamed";
  lockVersion = lock.version or "unknown";

  # First part is always "" and path doesn't start with /
  toPath = parts: let
    joined = b.concatStringsSep "/node_modules/" parts;
    len = b.stringLength joined;
    sliced = b.substring 1 len joined;
  in
    sliced;
  toParts = path: b.filter b.isString (b.split "/?node_modules/" path);

  getDep = name: parts:
    if b.length parts == 0
    then null
    else pkgs.${toPath (parts ++ [name])} or (getDep name (lib.init parts));
  resolveDep = name: parts: isOptional: let
    dep = getDep name parts;
  in
    if dep == null
    then
      if !isOptional
      then b.abort "Cannot resolve dependency ${name} from ${parts}"
      else null
    else {
      inherit name;
      inherit (dep) version;
    };
  resolveDeps = nameSet: parts: isOptional:
    if nameSet == null
    then []
    else let
      depNames = b.attrNames nameSet;
      resolved = b.map (n: resolveDep n parts isOptional) depNames;
    in
      b.filter (d: d != null) resolved;

  mapPkg = path: let
    parts = toParts path;
    pname = let
      n = lib.last parts;
    in
      if n == ""
      then lockName
      else n;

    extraAttrs = {
      # platforms this package works on
      os = 1;
      # this is a dev dependency
      dev = 1;
      # this is an optional dependency
      optional = 1;
      # this is an optional dev dependency
      devOptional = 1;
      # set of binary scripts { name = relativePath }
      bin = 1; # pkg needs to run install scripts
      hasInstallScript = 1;
    };
    getExtra = pkg: b.intersectAttrs extraAttrs pkg;
  in
    {
      version ? "unknown",
      # URL to content - only main package is not defined
      resolved ? "file://${source}",
      # hash for content
      integrity ? null,
      dependencies ? null,
      devDependencies ? null,
      peerDependencies ? null,
      optionalDependencies ? null,
      peerDependenciesMeta ? null,
      ...
    } @ pkg: let
      deps =
        lib.unique
        ((resolveDeps dependencies parts false)
          ++ (resolveDeps devDependencies parts true)
          ++ (resolveDeps optionalDependencies parts true)
          ++ (resolveDeps peerDependencies parts true)
          ++ (resolveDeps peerDependenciesMeta parts true));
    in {
      inherit pname version deps;
      url = resolved;
      hash = integrity;
      extra = getExtra pkg;
    };

  allDeps = lib.mapAttrsToList mapPkg pkgs;
  self = lib.findFirst (d: d.pname == lockName && d.version == lockVersion) (b.abort "Could not find main package") allDeps;
in {inherit allDeps self;}
