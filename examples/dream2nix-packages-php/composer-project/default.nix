{
  lib,
  config,
  dream2nix,
  ...
}: {
  imports = [
    dream2nix.modules.drv-parts.php-composer-lock
    dream2nix.modules.drv-parts.php-granular
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "Gipetto";
      repo = "CowSay";
      rev = config.version;
      sha256 = "sha256-jriyCzmvT2pPeNQskibBg0Bsh+h64cAEO+yOOfX2wbA=";
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
  version = "1.2.0";
}
