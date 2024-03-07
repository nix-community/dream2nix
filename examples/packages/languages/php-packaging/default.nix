{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.dream2nix.php-composer-lock
    dream2nix.modules.dream2nix.php-granular
  ];

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  name = "cowsay";
  version = "1.2.0";

  php-composer-lock = {
    source = config.deps.fetchFromGitHub {
      owner = "Gipetto";
      repo = "CowSay";
      rev = config.version;
      sha256 = "sha256-jriyCzmvT2pPeNQskibBg0Bsh+h64cAEO+yOOfX2wbA=";
    };
  };

  mkDerivation = {
    src = config.php-composer-lock.source;
  };
}
