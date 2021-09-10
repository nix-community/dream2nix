{
  callPackage,
}:
rec {
  defaultFetcher = callPackage ./default-fetcher.nix {};
  
  combinedFetcher = callPackage ./combined-fetcher.nix { inherit defaultFetcher; };
}
