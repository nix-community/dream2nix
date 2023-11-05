# This file provides backward compatibility to nix < 2.4 clients
let
  flake =
    import
    ./dev-flake/flake-compat.nix
    {src = ./.;};
in
  flake.defaultNix
  # allow overriding inputs
  // {
    __functor = defaultNix: inputs: defaultNix.overrideInputs inputs;
  }
