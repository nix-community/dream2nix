{lib, ...}: let
  # path = node_modules/@org/lib/node_modules/bar
  stripPath = path: let
    split = lib.splitString "node_modules/" path; # = [ "@org/lib" "bar" ]
    suffix = "node_modules/${lib.last split}"; # = "node_modules/bar"
    nextPath = lib.removeSuffix suffix path; # = "node_modules/@org/lib/node_modules/bar";
  in
    lib.removeSuffix "/" nextPath;

  sanitizeLockfile = lock:
  # This lockfile module only supports lockfileVersion 2 and 3
    if ! lock ? lockfileVersion || lock.lockfileVersion <= 1
    then throw "This lockfile module only supports lockfileVersion 2 and 3"
    else lock;

  findEntry =
    # = "attrs"
    packageLock:
    # = "my-package/node_modules/@foo/bar"
    currentPath:
    # = "kitty"
    search: let
      searchPath = lib.removePrefix "/" "${currentPath}/node_modules/${search}"; # = "my-package/node_modules/@foo/bar/node_modules/kitty"
    in
      if packageLock.packages ? ${searchPath}
      then
        # attribute found in plock
        searchPath
      else if currentPath == ""
      then throw "${search} not found in package-lock.json."
      else findEntry packageLock (stripPath currentPath) search;
in {
  inherit findEntry stripPath sanitizeLockfile;
}
