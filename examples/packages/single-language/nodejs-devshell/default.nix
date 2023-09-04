{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-devshell
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "piuccio";
      repo = "cowsay";
      rev = "v1.5.0";
      sha256 = "sha256-TZ3EQGzVptNqK3cNrkLnyP1FzBd81XaszVucEnmBy4Y=";
    };
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      mkShell
      rsync
      stdenv
      ;
  };

  name = "cowsay";
  version = "1.5.0";
}
