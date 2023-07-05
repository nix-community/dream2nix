{
  lib,
  config,
  dream2nix,
  ...
}: let
  l = lib // builtins;
  system = config.deps.stdenv.system;
in {
  imports = [
    dream2nix.modules.drv-parts.nodejs-floco
    dream2nix.modules.drv-parts.nodejs-floco-package-lock
  ];

  name = l.mkForce "prettier";
  version = l.mkForce "2.8.7";

  lock.lockFileRel =
    l.mkForce "/v1/nix/modules/drvs/prettier-floco/lock-${system}.json";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
    nodejs = nixpkgs.nodejs-16_x;
  };

  nodejs-floco.source = builtins.fetchTarball {
    url = "https://github.com/davhau/prettier/tarball/2.8.7-package-lock";
    sha256 = "sha256-zo+WRV3VHja8/noC+iPydtbte93s5GGc3cYaQgNhlEY=";
  };

  nodejs-floco.modules = [
    {
      floco.settings.nodePackage = config.deps.nodejs;
      floco.pdefs.esbuild."0.16.10".lifecycle.install = l.mkForce false;
    }
  ];

  nodejs-floco-package-lock = {
    lockDir = config.nodejs-floco.source;
  };
}
