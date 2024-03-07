{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-node-modules
    dream2nix.modules.dream2nix.nodejs-package-lock
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      mkShell
      stdenv
      ;
  };

  nodejs-package-lock = {
    source = config.deps.fetchFromGitHub {
      owner = "piuccio";
      repo = "cowsay";
      rev = "v1.5.0";
      sha256 = "sha256-TZ3EQGzVptNqK3cNrkLnyP1FzBd81XaszVucEnmBy4Y=";
    };
  };

  name = "cowsay";
  version = "1.5.0";
  mkDerivation = {
    src = config.nodejs-package-lock.source;
  };
}
