# This is currently only used for legacy modules ported to v1.
# The dream-lock concept might be deprecated together with this module at some
#   point.
{lib, ...}: let
  l = builtins // lib;

  nameVersionPair = name: version: {
    name = name;
    version = version;
  };

  findCycles = {
    dependencyGraph,
    roots,
  }: let
    depGraphWithFakeRoot =
      l.recursiveUpdate
      dependencyGraph
      {
        __fake-entry.__fake-version =
          l.mapAttrsToList
          nameVersionPair
          roots;
      };

    findCycles_ = node: prevNodes: cycles: let
      children =
        depGraphWithFakeRoot."${node.name}"."${node.version}";

      cyclicChildren =
        l.filter
        (child: prevNodes ? "${child.name}#${child.version}")
        children;

      nonCyclicChildren =
        l.filter
        (child: ! prevNodes ? "${child.name}#${child.version}")
        children;

      cycles' =
        cycles
        ++ (l.map (child: {
            from = node;
            to = child;
          })
          cyclicChildren);

      # use set for efficient lookups
      prevNodes' =
        prevNodes
        // {"${node.name}#${node.version}" = null;};
    in
      if nonCyclicChildren == []
      then cycles'
      else
        l.flatten
        (l.map
          (child: findCycles_ child prevNodes' cycles')
          nonCyclicChildren);

    cyclesList =
      findCycles_
      (
        nameVersionPair
        "__fake-entry"
        "__fake-version"
      )
      {}
      [];
  in
    l.foldl'
    (cycles: cycle: (
      let
        existing =
          cycles."${cycle.from.name}"."${cycle.from.version}"
          or [];

        reverse =
          cycles."${cycle.to.name}"."${cycle.to.version}"
          or [];
      in
        # if edge or reverse edge already in cycles, do nothing
        if
          l.elem cycle.from reverse
          || l.elem cycle.to existing
        then cycles
        else
          l.recursiveUpdate
          cycles
          {
            "${cycle.from.name}"."${cycle.from.version}" =
              existing ++ [cycle.to];
          }
    ))
    {}
    cyclesList;
in
  findCycles
