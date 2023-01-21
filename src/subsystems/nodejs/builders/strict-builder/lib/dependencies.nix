{
  lib,
  getDependencies,
  deps,
  allPackages,
}: let
  # l = lib // builtins;
  b = builtins;
  # appends the given dependencyAttrs into the dependencyTree
  # at location `tree.${dep.name}.${dep.version}`
  #
  # type:
  #  makeDepAttrs :: {
  #    deps :: DependencyTree,
  #    dep :: Dependency,
  #    attributes :: DependencyAttrs
  #   } -> DependencyTree
  #
  #  Dependency :: { name :: String, version :: String }
  #  DependencyAttrs :: { { deps :: DependencyTree, derivation :: Derivation } }
  #  DependencyTree :: { ${name} :: { ${version} :: DependencyAttrs } }
  insertDependencyAttrs = {
    dep,
    dependencyTree,
    dependencyAttrs,
  }:
    dependencyTree
    // {
      ${dep.name} =
        (dependencyTree.${dep.name} or {})
        // {
          ${dep.version} =
            (dependencyTree.${dep.name}.${dep.version} or {})
            // dependencyAttrs;
        };
    };

  # The fully rendered dependency tree.
  # "Who depends on whom"
  # needed because nix needs to know the order in which derivations must be built.
  # "Dependencies must be built from bottom to top"
  #
  # type: depsTree :: DependencyTree
  # (see insertDependencyAttrs for declaration)
  depsTree = let
    getDeps = tree: (b.foldl'
      (
        dependencyTree: dep:
          insertDependencyAttrs {
            inherit dependencyTree dep;
            dependencyAttrs = {
              deps = getDeps (getDependencies dep.name dep.version);
              derivation = allPackages.${dep.name}.${dep.version}.lib;
            };
          }
      )
      {}
      tree);
  in (getDeps deps);
in {
  inherit depsTree;
}
