# This file provides backward compatibility to nix < 2.4 clients
let
  flake =
    import
    (
      let
        lock = builtins.fromJSON (builtins.readFile ./dev-flake/flake.lock);
      in
        fetchTarball {
          url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
          sha256 = lock.nodes.flake-compat.locked.narHash;
        }
    )
    {src = ./.;};
in
  flake.defaultNix
  # allow overriding inputs
  // {
    __functor = defaultNix: inputs: defaultNix.overrideInputs inputs;
  }

