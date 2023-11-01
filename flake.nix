{
  description = "Simplified nix packaging for various programming language ecosystems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    pyproject-nix.url = "github:adisbladis/pyproject.nix";
    pyproject-nix.flake = false;

    purescript-overlay.url = "github:thomashoneyman/purescript-overlay";
    purescript-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    inherit
      (builtins)
      mapAttrs
      readDir
      ;

    inherit
      (inputs.nixpkgs.lib)
      filterAttrs
      mapAttrs'
      removeSuffix
      ;

    devFlake = import ./dev-flake;

    modulesDir = ./modules;

    moduleKinds =
      filterAttrs (_: type: type == "directory") (readDir modulesDir);

    mapModules = kind:
      mapAttrs'
      (fn: _: {
        name = removeSuffix ".nix" fn;
        value = modulesDir + "/${kind}/${fn}";
      })
      (readDir (modulesDir + "/${kind}"));
  in{
    inherit
      (devFlake)
      checks
      devShells
      lib
      packages
      ;
    modules = mapAttrs (kind: _: mapModules kind) moduleKinds;
  };
}
