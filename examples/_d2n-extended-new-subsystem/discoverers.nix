{dlib, ...}: {
  discoverers.dummy = rec {
    name = "dummy";
    subsystem = "hello";
    discover = {tree}: [
      (dlib.construct.discoveredProject {
        inherit subsystem name;
        inherit (tree) relPath;
        translators = ["dummy"];
        subsystemInfo = {};
      })
    ];
  };
}
