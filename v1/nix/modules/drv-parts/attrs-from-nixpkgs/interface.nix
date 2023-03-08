{config, lib, ...}: let
  l = lib // builtins;
  t = l.types;

in {
  options.attrs-from-nixpkgs = {

    lib.extractOverrideAttrs = l.mkOption {
      type = t.functionTo t.attrs;
      description = ''
        Helper function to extract attrs from nixpkgs to be re-used as overrides.
      '';
      readOnly = true;
    };

    # Extracts derivation args from a nixpkgs python package.
    lib.extractPythonAttrs = l.mkOption {
      type = t.functionTo t.attrs;
      description = ''
        Helper function to extract python attrs from nixpkgs to be re-used as overrides.
      '';
      readOnly = true;
    };

  };
}
