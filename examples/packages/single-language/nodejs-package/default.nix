{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-lock
    dream2nix.modules.dream2nix.nodejs-granular
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "piuccio";
      repo = "cowsay";
      rev = "v1.5.0";
      sha256 = "sha256-TZ3EQGzVptNqK3cNrkLnyP1FzBd81XaszVucEnmBy4Y=";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  name = "cowsay";
  version = "1.5.0";
}
