{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
in {
  imports = [
    ../../drv-parts/nodejs-floco
  ];

  name = l.mkForce "prettier-floco";
  version = l.mkForce "2.8.8";

  deps = {nixpkgs, ...}: {
    inherit
      (nixpkgs)
      fetchFromGitHub
      stdenv
      ;
  };

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "prettier";
      repo = "prettier";
      # workaround for unsupported 'git+ssh://git@github.com/ikatyang/parse-srcset.git'
      # dep in released version
      rev = "348f9fd409860dbdef9baf2c759820f37c065031";
      sha256 = "sha256-cbPWqCjZFw1u/3YgBSPwfjZVN3OM3GF2tbN5gfsmjTA=";
    };
  };

  nodejs-floco.modules = [
    {
      floco.settings.basedir = ./.;
      floco.pdefs.prettier."3.0.0-alpha.6".fetchInfo.path = l.mkForce config.mkDerivation.src.outPath;
    }
  ];
}
