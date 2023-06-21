{
  config,
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
    l.filterAttrs
    (
      name: _:
        ! (
          extractedMkDerivation
          ? ${name}
          || extractedBuildPythonPackage ? ${name}
        )
    )
    extracted;
in {
  imports = [
    ./interface.nix
  ];

  config = l.mkMerge [
    (l.mkIf cfg.enable {
      mkDerivation = extractedMkDerivation;
      buildPythonPackage = extractedBuildPythonPackage;
      env = extractedEnv;
    })
    {
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
    }
  ];
}
