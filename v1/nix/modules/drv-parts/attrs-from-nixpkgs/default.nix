{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

  # Attributes we never want to copy from nixpkgs
  excludedNixpkgsAttrs = l.genAttrs
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

in {
  imports = [
    ./interface.nix
  ];

  config.attrs-from-nixpkgs.lib = { inherit extractOverrideAttrs extractPythonAttrs; };
}
