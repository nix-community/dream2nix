let
  b = builtins;
  flakeCompatSrc = b.fetchurl "https://raw.githubusercontent.com/edolstra/flake-compat/12c64ca55c1014cdc1b16ed5a804aa8576601ff2/default.nix";
  flake = (import flakeCompatSrc {src = ./.;}).defaultNix;
  pkgs = import flake.inputs.nixpkgs {};
  mapRecurse = attrs: f:
    b.mapAttrs f attrs
    // {
      recurseForDerivations = true;
    };
in
  mapRecurse
  {
    # FIXME: We can't lock via remote-builders yet, and I don't have a aarch64-linux
    # machine here, so we lack lock files for the evaluation atm.
    # aarch64-linux = {};
    x86_64-linux = {};
    x86_64-darwin = {};
    aarch64-darwin = {};
  }
  (
    system: {knownIssues ? {}}:
      mapRecurse
      {
        checks = flake.checks.${system};
        packages = pkgs.lib.filterAttrs (n: v: ! b.hasAttr n knownIssues) flake.packages.${system};
      }
      (_name: val: pkgs.recurseIntoAttrs val)
  )
