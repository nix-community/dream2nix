{
  config,
  lib,
  options,
  ...
}: let
  l = lib // builtins;
  cfg = config.nixpkgs-overrides;

  # Attributes we never want to copy from nixpkgs
  excludedNixpkgsAttrs =
    l.genAttrs
    [
      "all"
      "args"
      "builder"
      "name"
      "pname"
      "version"
      "src"
      "outputs"
    ]
    (name: null);

  extractOverrideAttrs = overrideFunc:
    (overrideFunc (old: {passthru.old = old;}))
    .old;

  extractPythonAttrs = pythonPackage: let
    pythonAttrs = extractOverrideAttrs pythonPackage.overridePythonAttrs;
  in
    l.filterAttrs (name: _: ! excludedNixpkgsAttrs ? ${name}) pythonAttrs;

  extracted = extractPythonAttrs config.deps.python.pkgs.${config.public.name};
in {
  imports = [
    ./interface.nix
  ];

  config = l.mkIf cfg.enable {
    package-func.args = extracted;
  };
}
