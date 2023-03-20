{
  config,
  lib,
  options,
  ...
}: let
  l = lib // builtins;
  cfg = config.nixpkgs-overrides;

  excludedNixpkgsAttrs =
    l.genAttrs cfg.excludedNixpkgsAttrs (name: null);

  extractOverrideAttrs = overrideFunc:
    (overrideFunc (old: {passthru.old = old;}))
    .old;

  extractPythonAttrs = pythonPackage: let
    pythonAttrs = extractOverrideAttrs pythonPackage.overridePythonAttrs;
  in
    l.filterAttrs (name: _: ! excludedNixpkgsAttrs ? ${name}) pythonAttrs;

  extracted =
    if config.deps.python.pkgs ? config.name
    then extractPythonAttrs config.deps.python.pkgs.${config.name}
    else {};
in {
  imports = [
    ./interface.nix
  ];

  config = l.mkMerge [
    (l.mkIf cfg.enable {
      package-func.args = extracted;
    })
    {
      nixpkgs-overrides.lib = {inherit extractOverrideAttrs extractPythonAttrs;};
    }
  ];
}
