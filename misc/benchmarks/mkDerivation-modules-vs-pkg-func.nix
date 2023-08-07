{dream2nixSource ? ../..}: let
  dream2nix = import dream2nixSource;
  nixpkgs = import dream2nix.inputs.nixpkgs {};
  lib = nixpkgs.lib;

  _callModule = module:
    nixpkgs.lib.evalModules {
      specialArgs.dream2nix = dream2nix;
      specialArgs.packageSets.nixpkgs = nixpkgs;
      modules = [module dream2nix.modules.drv-parts.core];
    };

  # like callPackage for modules
  callModule = module: (_callModule module).config.public;

  numPkgs = lib.toInt (builtins.getEnv "NUM_PKGS");

  pkg-funcs = lib.genAttrs (map toString (lib.range 0 numPkgs)) (
    num:
      nixpkgs.stdenv.mkDerivation rec {
        pname = "hello-${num}";
        version = "2.12.1";
        src = nixpkgs.fetchurl {
          url = "mirror://gnu/hello/hello-${version}.tar.gz";
          sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
        };
        doCheck = false;
      }
  );

  modules = lib.genAttrs (map toString (lib.range 0 numPkgs)) (num:
    callModule rec {
      imports = [
        dream2nix.modules.drv-parts.mkDerivation
      ];
      name = "hello-${num}";
      version = "2.12.1";
      deps.stdenv = nixpkgs.stdenv;
      mkDerivation = {
        src = nixpkgs.fetchurl {
          url = "mirror://gnu/hello/hello-${version}.tar.gz";
          sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
        };
      };
    });
in {
  inherit
    pkg-funcs
    modules
    ;
}
