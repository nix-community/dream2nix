{
  config,
  lib,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
  ];

  name = "hello";
  version = "2.12";

  deps = {nixpkgs, ...}: {
    inherit (nixpkgs) stdenv;
  };

  mkDerivation = {
    src = l.fetchTarball {
      url = "https://ftp.gnu.org/gnu/hello/hello-${config.version}.tar.gz";
      sha256 = "sha256-4GQeKLIxoWfYiOraJub5RsHNVQBr2H+3bfPP22PegdU=";
    };
  };
}
