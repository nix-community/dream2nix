{dlib, ...}: {
  discoverers.default = {subsystem, ...}: {
    discover = {tree}: [
      (dlib.construct.discoveredProject {
        inherit subsystem;
        inherit (tree) relPath;
        name = "hello";
        translators = ["dummy"];
        subsystemInfo = {};
      })
    ];
  };
}
