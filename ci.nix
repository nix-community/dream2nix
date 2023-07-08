let
  b = builtins;
  flakeCompatSrc = b.fetchurl "https://raw.githubusercontent.com/edolstra/flake-compat/12c64ca55c1014cdc1b16ed5a804aa8576601ff2/default.nix";
  flake = (import flakeCompatSrc {src = ./.;}).defaultNix;
  pkgs = import flake.inputs.nixpkgs {};
  recurseIntoAll = b.mapAttrs (name: val: pkgs.recurseIntoAttrs val);
in
  recurseIntoAll {
    checks = flake.checks.x86_64-linux;
    packages = flake.packages.x86_64-linux;
  }
