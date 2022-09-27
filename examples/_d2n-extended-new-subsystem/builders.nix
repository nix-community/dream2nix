{
  builders.dummy = {...}: {
    name = "dummy";
    subsystem = "hello";
    type = "pure";
    build = {hello, ...}: {...}: {
      packages.${hello.pname}.${hello.version} =
        hello;
    };
  };
}
