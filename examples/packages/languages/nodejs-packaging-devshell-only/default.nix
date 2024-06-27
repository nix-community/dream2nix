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
    src = builtins.fetchGit {
      shallow = true;
      url = "https://github.com/DavHau/cowsay";
      ref = "package-lock-v3";
      rev = "c89952cb75e3e54b8ca0033bd3499297610083c7";
    };
    # allow devshell to be built -> CI pipeline happy
    buildPhase = "mkdir $out";
  };
}
