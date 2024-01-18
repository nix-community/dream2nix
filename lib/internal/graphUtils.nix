/*
A collection of tools needed to interact with graphs (i.e. A dependencyTree)
*/
{lib, ...}: let
  l = lib // builtins;

  # debugMsg = msg: val: builtins.trace "${msg} ${(builtins.toJSON val)}" val;

  /*
  Internal function. sanitize a potentially cyclic graph. Returns all items interconnected but with at least connections as possible.

  # Params

  - graph :: { ${path} :: [ [ string ] ] }
  GenericGraph; An AttrSet of nodeIds, pointing to neighboring nodes. (could be cyclic).

  - roots :: [ String ]
  A list of root ids

  # Returns

  (inverted) GenericGraph without cycles.

  GenericGraph :: [ { key :: String; parent :: String; } ]
  */
  # returns
  /*
  [
    {
      name :: String;
      version :: String;

      // True if the parent requires as dev dependency
      dev :: Bool;
      isRoot? :: true;
      // Needed for generic closure
      key :: [ name version];
    }
  ]
  */
  # TODO(hsjobeki): inherit dev attribute lazy
  sanitizeGraph = {
    graph,
    root,
    pred ? null,
  }:
    l.genericClosure {
      startSet = [
        {
          key = [root.name root.version];
          inherit (root) name version;
          isRoot = true;
        }
      ];
      operator = {key, ...} @ prev: let
        parentName = builtins.elemAt prev.key 0;
        parentVersion = builtins.elemAt prev.key 1;

        results =
          l.mapAttrsToList (
            name: depEntry: {
              key = [name depEntry.version];
              inherit name;
              inherit (depEntry) version;
              inherit (graph.${name}.${depEntry.version}) dev;
              parent = {
                name = parentName;
                version = parentVersion;
              };
            }
          )
          graph.${parentName}.${parentVersion}.dependencies;
      in
        l.filter (
          entry:
            if l.isFunction pred
            then pred entry && true
            else true
        )
        results;
      # if l.isFunction pred
      # then l.filter (entry: pred entry) results
      # else results;
    };

  /*
  Function that returns instructions to create the file system (aka. node_modules directory)
  Every `source` entry here is created. Bins are symlinked to their target.
  This behavior is implemented via the prepared-builder script.
  @argument pdefs'
  # The filtered and sanititized pdefs containing no cycles.
  # Only pdefs required by the current root and environment.
  # e.g. all buildtime dependencies of top-level package.
  []
  ->
  fileSystem :: {
    "node_modules/typescript": {
      source: <derivation typescript-dist>
      bins: {
        "node_modules/.bin/tsc": "node_modules/typescript/bin/tsc"
      }
    }
  }
  */
  getFileSystem = pdefs: pdefs':
    l.foldl' (
      /*
      set :: {
          name ::
          version ::
          dev ::
          isRoot ? :: true;
          key :: [];
      }

      */
      res: set: let
        filteredSet = l.filterAttrs (_: value: value.info.initialState == "dist") pdefs.${set.name};
      in
        res
        // l.foldl' (
          acc: version: let
            entry = filteredSet.${version};
          in
            acc
            // l.foldl' (res: path:
              if entry.info.allPaths.${path}
              then
                res
                // {
                  ${path} = {
                    source = entry.dist;
                    bins =
                      l.mapAttrs' (name: target: {
                        name = (builtins.dirOf path) + "/.bin/" + name;
                        value = path + "/" + target;
                      })
                      pdefs.${set.name}.${version}.bins;
                  };
                }
              else res) {} (l.attrNames (entry.info.allPaths))
        ) {} (l.attrNames filteredSet)
    ) {}
    pdefs';
in {
  inherit
    sanitizeGraph
    getFileSystem
    ;
}
