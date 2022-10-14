{config, ...}: let
  inherit (config.pkgs) hello;
in {
  builders.dummy = {...}: {
    name = "dummy";
    subsystem = "hello";
    type = "pure";
    build = {...}: {
      packages.${hello.pname}.${hello.version} =
        hello;
    };
  };
}
