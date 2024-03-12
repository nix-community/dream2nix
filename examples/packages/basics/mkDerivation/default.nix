{
  config,
  dream2nix,
  lib,
  ...
}: {
  # select mkDerivation as a backend for this package
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
    dream2nix.modules.dream2nix.flags
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchurl
      stdenv
      ;
  };

  flagsOffered = {
    enableFoo = "build with foo";
  };

  name =
    if config.flags.enableFoo
    then "hello-with-foo"
    else "hello";

  version = "2.12.1";

  mkDerivation = {
    src = config.deps.fetchurl {
      url = "mirror://gnu/hello/${config.name}-${config.version}.tar.gz";
      sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
    };
    doCheck = true;
  };
}
