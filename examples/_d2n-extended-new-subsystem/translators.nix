{config, ...}: let
  inherit (config.pkgs) hello;
in {
  translators.dummy = {...}: {
    type = "pure";
    name = "dummy";
    subsystem = "hello";
    translate = {...}: {
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
}
