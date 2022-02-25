{
  dlib,
  lib,
}:

let
  l = lib // builtins;

  subsystems = dlib.dirNames ./.;

  allDiscoverers =
    l.collect
      (v: v ? discover)
      discoverers;

  discoverProjects = source:
    let
      tree = dlib.prepareSourceTree { inherit source; };
    in
      l.flatten
        (l.map
          (discoverer: discoverer.discover { inherit tree; })
          allDiscoverers);

  discoverers = l.genAttrs subsystems (subsystem:
    (import (./. + "/${subsystem}") { inherit dlib lib subsystem; })
  );
in

{
  inherit
    discoverProjects
    discoverers
  ;
}
