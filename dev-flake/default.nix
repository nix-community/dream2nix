# This file provides backward compatibility to nix < 2.4 clients
let
  flake =
    import
    ./flake-compat.nix
    {src = ./.;};
in
  flake.defaultNix
