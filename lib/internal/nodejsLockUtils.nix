{lib, ...}: let
  # path = node_modules/@org/lib/node_modules/bar
  parentPath = path: let
    # noPackages = lib.removePrefix "packages/" path;
    packages = lib.splitString "node_modules/" path; # = [ "@org/lib" "bar" ]
    nextPath = lib.concatStringsSep "node_modules/" (lib.init packages);
  in
    lib.removeSuffix "/" (
      if path == nextPath
      then ""
      else nextPath
    );

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
      # if the package cannot be found as a sub-dependency, check the parent
      else findEntry packageLock (parentPath currentPath) search;
in {
  inherit findEntry parentPath;
}
