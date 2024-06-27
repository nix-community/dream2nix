{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.nodejs-package-lock-v3
    dream2nix.modules.dream2nix.nodejs-granular-v3
  ];

  mkDerivation = {
    src = builtins.fetchGit {
      shallow = true;
      url = "https://github.com/DavHau/cowsay";
      ref = "package-lock-v3";
      rev = "c89952cb75e3e54b8ca0033bd3499297610083c7";
    };
  };

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  nodejs-package-lock-v3 = {
    packageLockFile = "${config.mkDerivation.src}/package-lock.json";
  };

  name = "cowsay";
  version = "1.5.0";
}
