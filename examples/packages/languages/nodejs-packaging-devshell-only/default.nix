{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-devshell-v3
  ];

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

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "DavHau";
      repo = "cowsay";
      rev = "package-lock-v3";
      sha256 = "sha256-KuZkGWl5An78IFR5uT/2jVTXdm71oWB+p143svYVkqQ=";
    };
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
  };
}
