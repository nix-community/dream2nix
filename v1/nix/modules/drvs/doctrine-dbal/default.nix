{
  lib,
  config,
  dream2nix,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
    dream2nix.modules.drv-parts.php-composer-lock
    # dream2nix.modules.drv-parts.php-granular
  ];

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "aszenz";
      repo = "dbal";
      rev = "3.6.x";
      sha256 = "sha256-mZcV8L/YFhJUhFJLpS7NHti43E9+nJbpopeSwcKtOm4=";
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
