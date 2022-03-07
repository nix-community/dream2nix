let
  b = builtins;
  flakeCompatSrc = b.fetchurl "https://raw.githubusercontent.com/edolstra/flake-compat/12c64ca55c1014cdc1b16ed5a804aa8576601ff2/default.nix";
  flake = (import flakeCompatSrc {src = ./.;}).defaultNix;
  pkgs = import flake.inputs.nixpkgs {};
  recurseIntoAll = b.mapAttrs (name: val: pkgs.recurseIntoAttrs val);
in
  # {
  #   inherit flake;
  # }
  # // (recurseIntoAll {
  #   checks = flake.checks.x86_64-linux;
  # })
  # hercules ci's nix version cannot fetch submodules and crashes
  {
    inherit (pkgs) hello;
  }
