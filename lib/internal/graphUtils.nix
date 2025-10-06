/*
A collection of tools needed to interact with graphs (i.e. A dependencyTree)
*/
{lib, ...}: let
  l = lib // builtins;

  # debugMsg = msg: val: builtins.trace "${msg} ${(builtins.toJSON val)}" val;

  /*
  Internal function. sanitize a potentially cyclic graph. Returns all items interconnected but with at least connections as possible.

  # Params

  - Graph :: {
      ${name}.${version} :: {
        dependencies = {
          ${dep.name}.version = String;
        };
        dev :: Bool;
      };
    };

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
  getFileSystem = graph: sanitizedGraph:
    l.foldl' (
      /*
      sanitziedGraphEntry :: {
          name ::
          version ::
          dev ::
          isRoot ? :: true;
          key :: [];
      }
      */
      res: sanitizedGraphEntry: let
        /*

        filteredSet :: graph

        Example:

        All versions of "next" that are in the dist state.

        */
        distVersions = l.filterAttrs (_version: e: e.info.initialState == "dist") graph.${sanitizedGraphEntry.name};
      in
        res
        // l.foldlAttrs (
          acc: version: entry: let
            pdef = graph.${sanitizedGraphEntry.name}.${version};
          in
            acc
            // l.foldlAttrs (fileSystem: path: pathInfo:
              if pathInfo
              then
                fileSystem
                // getFileSystemInfo path pdef entry
              else fileSystem) {} entry.info.allPaths
        ) {}
        distVersions
    ) {}
    sanitizedGraph;

  getFileSystemInfo = path: pdef: entry: let
    info = {
      ${path} = {
        source = entry.dist;
        bins =
          l.mapAttrs' (name: target: {
            name = (builtins.dirOf path) + "/.bin/" + name;
            value = path + "/" + target;
          })
          pdef.bins;
      };
    };
  in
    info;
in {
  inherit
    sanitizeGraph
    getFileSystem
    ;
}
