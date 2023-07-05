{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/php-composer-lock
    ../../drv-parts/php-granular
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "aszenz";
      repo = "dbal";
      rev = "3.6.x";
      sha256 = "sha256-zo+WRV3VHja8/noC+iPydtbte93s5GGc3cYaQgNhlEY=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  name = l.mkForce "dbal";
  version = l.mkForce "3.6.4";
}
