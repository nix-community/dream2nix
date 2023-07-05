{
  lib,
  config,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  system = config.deps.stdenv.system;
  floco = (import "${dream2nix.inputs.floco.outPath}/flake.nix").outputs {inherit (packageSets) nixpkgs;};
in {
  imports = [
    ../../drv-parts/nodejs-floco
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
  };

  nodejs-floco.source = builtins.fetchTarball {
    url = "https://github.com/davhau/prettier/tarball/2.8.7-package-lock";
    sha256 = "0illc41l46n6vnf63r7cvmxyvmkny8izl0kszsy3c7nmbm2rd3yf";
  };

  nodejs-floco.modules = [
    {
      imports = [
        floco.nixosModules.plockToPdefs
        floco.nixosModules.useFetchZip
      ];
      config._module.args.lockDir = "${config.nodejs-floco.source}";
      config._module.args.pkgs = packageSets.nixpkgs;
      config.floco.buildPlan.deriveTreeInfo = false;
      config.floco.includePins = true;
      config.floco.includeRootTreeInfo = true;
    }
  ];
}
