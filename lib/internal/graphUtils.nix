/*
A collection of tools needed to interact with graphs (i.e. A dependencyTree)
*/
{lib, ...}: let
  l = lib // builtins;

  # debugMsg = msg: val: builtins.trace "${msg} ${(builtins.toJSON val)}" val;

  /*
  Internal function. sanitize a potentially cyclic graph. Returns all items interconnected but with at least connections as possible.

  # Params

  - graph :: { ${id} :: [ String ] }
  GenericGraph; An AttrSet of nodeIds, pointing to neighboring nodes. (could be cylic).

  - roots :: [ String ]
  A list of root ids

  # Returns

  (inverted) GenericGraph without cycles.

  GenericGraph :: [ { key :: String; parent :: String; } ]
  */
  __sanitizeGraph = {
    graph,
    roots,
  }:
    l.genericClosure {
      startSet = map (key: {inherit key;}) roots;
      operator = {key, ...} @ prev:
        map (
          key: {
            inherit key;
            parent = prev.key;
          }
        )
        graph.${prev.key};
    };

  /*
  Sanitize a potentially cyclic graph. Returns all items interconnected but with at least connections as possible.

  # Params

  - graph :: { ${id} :: [ String ] }
  Attribute set of nodeIds, pointing to neighboring nodes. (could be cylic).

  - roots :: [ String ]
  A list of root ids

  # Returns

  The same GenericGraph without cycles.

  GenericGraph :: { ${id} :: [ String ] }
  */
  sanitizeGraph = v: l.pipe v [__sanitizeGraph invertTree];

  # [ { key :: String; parent :: String; } ] -> GenericGraph :: { ${id} :: [ String ] }
  invertTree = l.foldl' (
    finalTree: item:
      if item ? parent
      then
        finalTree
        // {
          ${item.parent} = finalTree.${item.parent} or [] ++ [item.key];
          ${item.key} = finalTree.${item.key} or [];
        }
      else
        finalTree
        // {
          ${item.key} = finalTree.${item.key} or [];
        }
  ) {};

  # { name :: String; version :: String; } -> String
  fromNameVersionPair = {
    name,
    version,
  }: "${name}/${version}";

  # String -> { name :: String; version :: String; }
  identToNameVersionPair = str: let
    pieces = l.splitString "/" str;
    version = l.last pieces;
  in
    if pieces == [str]
    then {
      name = str;
      version = "unknown";
    }
    else {
      inherit version;
      name = l.concatStringsSep "/" (l.filter (p: p != version) pieces);
    };

  /*
  Takes the "DependencyGraph" format (same format as findCycles)
  returns a GenericGraph :: { ${id} :: [ String ] }
  Can be used as an adapter method between 'findCycles' and 'sanitizeGraph';
  */
  fromDependencyGraph = depGraph:
    l.foldl' (
      res: name: let
        versions = l.attrNames depGraph.${name};
      in
        res
        // l.foldl' (
          acc: version:
            acc
            // {
              "${fromNameVersionPair {inherit name version;}}" = map fromNameVersionPair depGraph.${name}.${version};
            }
        ) {}
        versions
    ) {} (l.attrNames depGraph);

  /*
  Takes a GenericGraph and returns the "DependencyGraph" format

  Can be used as an adapter method between 'findCycles' and 'sanitizeGraph';

  # Example

  toDependencyGraph {
      "a/1.0.0" = ["@org/a/1.1.0"];
      "@org/a/1.1.0" = ["a/1.0.0"];
  }
  =>
  {
    "a"."1.0.0" = [
      {
        name = "@org/a";
        version = "1.1.0";
      }
    ];
    "@org/a"."1.1.0" = [
      {
        name = "a";
        version = "1.0.0";
      }
    ];
  };

  */
  toDependencyGraph = graph:
    l.foldl' (
      res: ident: let
        inherit (identToNameVersionPair ident) name version;
        deps = graph.${ident};
      in
        res // {${name} = res.${name} or {} // {${version} = res.${name}.${version} or [] ++ map identToNameVersionPair deps;};}
    ) {} (l.attrNames graph);
  ##########################################
  # Currently only used for legacy modules ported to v1.
in {
  inherit
    sanitizeGraph
    fromDependencyGraph
    identToNameVersionPair
    fromNameVersionPair
    toDependencyGraph
    ;
}
