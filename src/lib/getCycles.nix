# A cycle is when packages depend on each other
# The Nix store can't contain direct cycles, so cycles need special handling
# They can be avoided by referencing by name, so the consumer sets up the cycle
# internally, or by co-locating cycling packages in a single store path.
# Both approaches are valid, it depends on the situation what fits better.
#
# The below code detects cycles by visiting all edges of the dependency graph
# and keeping track of parents and already-visited nodes. Then it picks a head
# for each cycle, and the other members are referred to as cyclees.
# The head is the member with the shortest name, since that often results in a
# head that "feels right".
#
# The visits are tracked by maintaining state in the accumulator during folding.
{
  lib,
  dependencyGraph,
}: let
  b = builtins;

  # The separator char should never be in version
  mkTag = pkg: "${pkg.name}#${pkg.version}";
  mkTagSet = tag: value: lib.listToAttrs [(lib.nameValuePair tag value)];

  # discover cycles as sets with their members=true
  # a member is pkgname#pkgversion (# should not be in version string)
  # this walks dependencies depth-first
  # It will eventually see parents as children => cycle
  #
  # To visit only new nodes, we pass around state in parentAcc:
  # - visited: a set of already-visited packages
  # - cycles: a list of cycle sets
  # Parents are passed as a set of tag:depth for quick matching and ordering
  getCycles = {
    pkg,
    parents ? {},
    depth ? 0,
    parentAcc,
  }: let
    deps = dependencyGraph."${pkg.name}"."${pkg.version}";
    pkgTag = mkTag pkg;
    pkgDepth = mkTagSet pkgTag depth;

    visitOne = acc: dep: let
      depTag = mkTag dep;
      newParents = parents // pkgDepth;
    in
      if acc.visited ? "${depTag}"
      then
        # We will already have found all cycles it has, skip
        acc
      else if parents ? "${depTag}"
      then
        # We found a cycle
        let
          # All the packages between the cyclic parent-dep and pkg are a cycle
          cyclicDepth = parents.${depTag};
          cycle = lib.filterAttrs (tag: depth: depth >= cyclicDepth) newParents;
        in {
          visited = acc.visited;
          cycles = acc.cycles ++ [cycle];
        }
      else
        # We need to check this dep
        getCycles {
          pkg = dep;
          parents = newParents;
          depth = depth + 1;
          # Don't add pkg to visited until all deps are processed
          parentAcc = acc;
        };
    initialAcc = {
      visited = parentAcc.visited;
      cycles = [];
    };

    allVisited = b.foldl' visitOne initialAcc deps;
  in
    if parentAcc.visited ? "${pkgTag}"
    then
      # this can happen while walking the root nodes
      parentAcc
    else {
      visited = allVisited.visited // pkgDepth;
      cycles =
        if b.length allVisited.cycles != 0
        then mergeCycles parentAcc.cycles allVisited.cycles
        else parentAcc.cycles;
    };

  # merge cycles: We want a set of disjoined cycles
  # meaning, for each cycle of the set e.g. {a=true; b=true; c=true;...},
  # there is no other cycle that has any member (a,b,c,...) of this set
  # We maintain a set of already disjoint cycles and add a new cycle
  # by merging all cycles of the set that have members in common with
  # the cycle. The rest stays disjoint.
  mergeCycles = b.foldl' mergeOneCycle;
  mergeOneCycle = djCycles: cycle: let
    cycleDeps = b.attrNames cycle;
    includesDep = s: lib.any (n: s ? "${n}") cycleDeps;
    partitions = lib.partition includesDep djCycles;
    mergedCycle =
      if b.length partitions.right != 0
      then b.zipAttrsWith (n: v: true) ([cycle] ++ partitions.right)
      else cycle;
    disjoined = [mergedCycle] ++ partitions.wrong;
  in
    disjoined;

  # Walk all root nodes of the dependency graph
  allCycles = let
    mkHandleVersion = name: acc: version:
      getCycles {
        pkg = {inherit name version;};
        parentAcc = acc;
      };
    handleName = acc: name: let
      pkgVersions = b.attrNames dependencyGraph.${name};
      handleVersion = mkHandleVersion name;
    in
      b.foldl' handleVersion acc pkgVersions;

    initalAcc = {
      visited = {};
      cycles = [];
    };
    rootNames = b.attrNames dependencyGraph;

    allDone = b.foldl' handleName initalAcc rootNames;
  in
    allDone.cycles;

  # Convert list of cycle sets to set of cycle lists
  getCycleSets = cycles: b.foldl' lib.recursiveUpdate {} (b.map getCycleSetEntry cycles);
  getCycleSetEntry = cycle: let
    split = b.map toNameVersion (b.attrNames cycle);
    toNameVersion = d: let
      matches = b.match "^(.*)#([^#]*)$" d;
      name = b.elemAt matches 0;
      version = b.elemAt matches 1;
    in {inherit name version;};
    sorted =
      b.sort
      (x: y: let
        lenX = b.stringLength x.name;
        lenY = b.stringLength y.name;
      in
        if lenX < lenY
        then true
        else if lenX == lenY
        then
          if x.name < y.name
          then true
          else if x.name == y.name
          then x.version > y.version
          else false
        else false)
      split;
    head = b.elemAt sorted 0;
    cyclees = lib.drop 1 sorted;
  in {${head.name}.${head.version} = cyclees;};

  cyclicDependencies = getCycleSets allCycles;
in
  cyclicDependencies
