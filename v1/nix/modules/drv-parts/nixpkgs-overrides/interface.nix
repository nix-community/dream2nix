{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.nixpkgs-overrides = {
    enable = l.mkEnableOption "Whether to copy attributes, except those in `excluded` from nixpkgs";

    exclude = l.mkOption {
      type = t.listOf t.str;
      description = "Attributes we do not want to copy from nixpkgs";
      default = [
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
