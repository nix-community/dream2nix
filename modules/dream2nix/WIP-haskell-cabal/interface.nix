{
  lib,
  config,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.haskell-cabal = {};
}
