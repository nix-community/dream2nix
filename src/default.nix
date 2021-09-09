{
  pkgs ? import <nixpkgs> {},
}:

let
  callPackage = pkgs.callPackage;
in

rec {

  apps = callPackage ./apps { inherit location; };

  builders = callPackage ./builders {};

  fetchers = callPackage ./fetchers {};

  translators = callPackage ./translators {};


  # the location of the dream2nix framework for self references (update scripts, etc.)
  location = ./.;


  # automatically find a suitable builder for a given generic lock
  findBuilder = genericLock:
    let 
      buildSystem = genericLock.generic.buildSystem;
    in
      builders."${buildSystem}".default;


  # automatically build package defined by generic lock
  buildPackage = 
    {
      genericLock,
      builder ? findBuilder genericLock,
      fetcher ? fetchers.defaultFetcher
    }:
    builder {
      inherit genericLock;
      fetchedSources = fetcher { sources = genericLock.sources; };
    };
   
}