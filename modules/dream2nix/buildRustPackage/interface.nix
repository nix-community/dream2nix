{lib, ...}: {
  options.deps = {
    cargo = lib.mkOption {
      type = lib.types.package;
      description = "The cargo package to use";
    };
    writeText = lib.mkOption {
      type = lib.types.raw;
      description = "The function to use to write text to a file";
    };
  };
}
