# like ./default.nix but system intependent
# (allows to generate outputs for several systems)
# follows flake output schema

{
  nixpkgsSrc ? <nixpkgs>,
  lib ? (import nixpkgsSrc {}).lib,

  # (if called impurely ./default.nix will handle externals and overrides)
  externalSources ? null,
  overridesDir ? null,
}:

let

  b = builtins;

  # TODO: design output schema for cross compiled packages
  makePkgsKey = pkgs:
    let
      build = pkgs.buildPlatform.system;
      host = pkgs.hostPlatform.system;
    in
      if build == host then build
      else throw "cross compiling currently not supported";

  makeNixpkgs = pkgsList: systems:

    # fail if neither pkgs nor systems are defined
    if pkgsList == null && systems == [] then
      throw "Either `systems` or `pkgs` must be defined"

    # fail if pkgs and systems are both defined
    else if pkgsList != null && systems != [] then
      throw "Define either `systems` or `pkgs`, not both"
    
    # only pkgs is specified
    else if pkgsList != null then
      if b.isList pkgsList then
        lib.listToAttrs
          (pkgs: lib.nameValuePair (makePkgsKey pkgs) pkgs)
          pkgsList
      else
        { "${makePkgsKey pkgsList}" = pkgsList; }
    
    # only systems is specified
    else
      lib.genAttrs systems
        (system: import nixpkgsSrc { inherit system; });

    
    flakifyBuilderOutputs = system: outputs:
      (lib.optionalAttrs (outputs ? "defaultPackage") {
        defaultPackage."${system}" = outputs.defaultPackage;
      })
      //
      (lib.optionalAttrs (outputs ? "packages") {
        packages."${system}" = outputs.packages;
      })
      //
      (lib.optionalAttrs (outputs ? "devShell") {
        devShell."${system}" = outputs.devShell;
      });

in

{
  riseAndShine = 
    {
      pkgs ? null,
      systems ? [],
      ...
    }@args:
    let

      argsForward = b.removeAttrs args [ "pkgs" "systems" ];

      allPkgs = makeNixpkgs pkgs systems;

      dream2nixFor =
        lib.mapAttrs
          (system: pkgs:
            import ./default.nix
              ({ inherit pkgs; }
              // (lib.optionalAttrs (externalSources != null) {
                inherit externalSources;
              })
              // (lib.optionalAttrs (overridesDir != null) {
                inherit overridesDir;
              })))
          allPkgs;

      allBuilderOutputs =
        lib.mapAttrs
          (system: pkgs:
            dream2nixFor."${system}".riseAndShine argsForward)
          allPkgs;

      flakifiedOutputs =
        lib.mapAttrsToList
          (system: outputs: flakifyBuilderOutputs system outputs)
          allBuilderOutputs;
      
    in
      b.foldl'
        (allOutputs: output: lib.recursiveUpdate allOutputs output)
        {}
        flakifiedOutputs;
}