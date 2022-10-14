{config, ...}: {
  discoverers.dummy = rec {
    name = "dummy";
    subsystem = "hello";
    discover = {tree}: [
      (config.dlib.construct.discoveredProject {
        inherit subsystem name;
        inherit (tree) relPath;
        translators = ["dummy"];
        subsystemInfo = {};
      })
    ];
  };
}
