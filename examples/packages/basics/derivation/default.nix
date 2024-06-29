{
  config,
  dream2nix,
  lib,
  ...
}: {
  # select builtins.derivation as a backend for this package
  imports = [
    dream2nix.modules.dream2nix.builtins-derivation
  ];

  name = "test";

  # set options
  builtins-derivation = {
    builder = "/bin/sh";
    args = ["-c" "echo $name > $out"];
  };
}
