{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    overridesDirs = l.mkOption {
      type = t.listOf t.path;
      default = [];
      description = ''
        Override directories to pull overrides from.
      '';
    };
    packagesDir = l.mkOption {
      type = t.str;
      default = "./dream2nix-packages";
      description = ''
        Relative path to the project root to put generated dream-lock files in.
      '';
    };
    projectRoot = l.mkOption {
      type = t.nullOr t.path;
      default = null;
      description = ''
        Absolute path to the root of this project.
      '';
    };
    repoName = l.mkOption {
      type = t.nullOr t.str;
      default = null;
      description = ''
        Name of the repository this project is in.
      '';
    };
    modules = l.mkOption {
      type = t.listOf (t.oneOf [t.attrs t.path (t.functionTo t.attrs)]);
      default = [];
      description = ''
        Extra modules to import in while evaluating the dream2nix framework.
        This allows you to add new discoverers, translators, builders etc. and lets you override existing ones.
      '';
    };
  };
}
