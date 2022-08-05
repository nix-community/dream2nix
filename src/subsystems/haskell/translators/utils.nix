{lib}: let
  l = lib // builtins;
in {
  getHackageUrl = {
    name,
    version,
    ...
  }: "https://hackage.haskell.org/package/${name}-${version}.tar.gz";
}
