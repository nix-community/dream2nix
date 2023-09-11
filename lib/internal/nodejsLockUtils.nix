{lib, ...}: let
  # path = node_modules/@org/lib/node_modules/bar
  stripPath = path: let
    split = lib.splitString "node_modules/" path; # = [ "@org/lib" "bar" ]
    suffix = "node_modules/${lib.last split}"; # = "node_modules/bar"
    nextPath = lib.removeSuffix suffix path; # = "node_modules/@org/lib/node_modules/bar";
  in
    lib.removeSuffix "/" nextPath;

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

   # Returns the names of all "bundledDependencies".
   # People depend on different types and different names. Unfortunatly those fields are not part of the offical npm documentation.
   # Which may also be the reason for the mess.
   # 
   # TODO: define unit tests.
   # Adopted from https://github.com/aakropotkin/floco/blob/708c4ffa0c05033c29fe6886a238cb20c3ba3fb4/modules/plock/implementation.nix#L139
   # 
   # getBundledDependencies :: Pent -> {}
   getBundledDependencies = pent: let
        # b :: bool | []
        b = pent.bundledDependencies or pent.bundleDependencies or [];
    in  
        # The following asserts is the XOR logic.
        # "bundle" and "bundled" dependencies are both valid but invalid if both or none keys exist
        assert     ( pent ? bundledDependencies ) ->
              ( ! ( pent ? bundleDependencies  ) );
        assert     ( pent ? bundleDependencies  ) ->
              ( ! ( pent ? bundledDependencies ) );
        if b == [] then {} else
        if builtins.isList b then { bundledDependencies = b; } else
        if ! b then {} else {
        # b :: true
        bundledDependencies = builtins.attrNames (
          ( pent.dependencies or {} ) // ( pent.requires or {} )
        );
    };
in {
  inherit findEntry stripPath getBundledDependencies;
}
