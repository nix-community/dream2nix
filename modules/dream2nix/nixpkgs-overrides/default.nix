{
  config,
  dream2nix,
  lib,
  options,
  ...
}: let
  l = lib // builtins;
  cfg = config.nixpkgs-overrides;

  exclude =
    l.genAttrs cfg.exclude (name: null);

  extractOverrideAttrs = overrideFunc:
    (overrideFunc (old: {passthru.old = old;}))
    .old;

  extractPythonAttrs = pythonPackage: let
    pythonAttrs =
      extractOverrideAttrs
      (pythonPackage.overridePythonAttrs or pythonPackage.overrideAttrs);
  in
    l.filterAttrs (name: _: ! exclude ? ${name}) pythonAttrs;

  extracted =
    if cfg.from != null
    then extractPythonAttrs cfg.from
    else {};

  extractedMkDerivation =
    l.intersectAttrs
    options.mkDerivation
    extracted;

  extractedBuildPythonPackage =
    l.intersectAttrs
    options.buildPythonPackage
    extracted;

  extractedEnv =
    (l.filterAttrs
      (
        name: _:
          ! (
            extractedMkDerivation
            ? ${name}
            || extractedBuildPythonPackage ? ${name}
          )
          && name != "env"
      )
      extracted)
    // extracted.env or {};
in {
  imports = [
    ./interface.nix
    dream2nix.modules.dream2nix.buildPythonPackage
  ];

  config =
    {
      mkDerivation = lib.mkIf cfg.enable extractedMkDerivation;
      buildPythonPackage = lib.mkIf cfg.enable extractedBuildPythonPackage;
      env = lib.mkIf cfg.enable extractedEnv;
    }
    // {
      nixpkgs-overrides.lib = {inherit extractOverrideAttrs extractPythonAttrs;};
      nixpkgs-overrides.exclude = [
        "all"
        "args"
        "builder"
        "name"
        "pname"
        "version"
        "src"
        "outputs"
      ];
    };
}
