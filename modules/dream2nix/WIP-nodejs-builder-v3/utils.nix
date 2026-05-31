{lib}: let
  l = lib // builtins;

  nodejsLockUtils = import ../../../lib/internal/nodejsLockUtils.nix {inherit lib;};
  graphUtils = import ../../../lib/internal/graphUtils.nix {inherit lib;};

  isLink = plent: plent ? link && plent.link;

  getInfo = path: plent: {
    initialPath = path;
    initialState =
      if
        isLink plent
        ||
        /*
        IsRoot
        */
        path == ""
      then "source"
      else "dist";
  };

  /*
  *
  A Convinient wrapper around sanitizeGraph
  which allows to pass options such as { dev=false; }

  */
  getSanitizedGraph = {
    # The lockfile entry; One depdency used as a root.
    plent,
    # The dependency 'graph'. See: sanitizeGraph
    pdefs,
    /*
    *
    Drops dependencies including their subtree connection by filter attribute.

    for example:

    ```
    filterTree = {
      dev = false;
    };
    ```

    Will filter out all dev dependencies including all children below dev-dependencies.

    Which will result in a prod only tree.
    */
    filterTree ? {},
  }: let
    root = {
      inherit (plent) name;
      inherit (plent) version;
    };
    graph = pdefs;
  in
    graphUtils.sanitizeGraph {
      inherit root graph;
      pred = e:
          l.foldlAttrs (
            res: name: value:
              if !res
              then false
              else value == e.${name}
          )
          true
          filterTree;
    };
in {
  inherit getInfo getSanitizedGraph;
}
