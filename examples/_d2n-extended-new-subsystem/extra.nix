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
    translators.dummy = {...}: {
      type = "pure";
      translate = {hello, ...}: {...}: {
        result = {
          _generic = {
            subsystem = "hello";
            defaultPackage = "hello";
            location = "";
            sourcesAggregatedHash = null;
            packages = {${hello.pname} = hello.version;};
          };
          _subsystem = {};
          cyclicDependencies = {};
          dependencies.${hello.pname}.${hello.version} = [];
          sources.${hello.pname}.${hello.version} = {
            type = "http";
            url = hello.src.url;
            hash = hello.src.outputHash;
          };
        };
      };
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
