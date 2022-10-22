{dlib, ...}: {
  subsystems.hello = {
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
    builders.dummy = {...}: {
      type = "pure";
      build = {hello, ...}: {...}: {
        packages.${hello.pname}.${hello.version} =
          hello;
      };
    };
  };
}
