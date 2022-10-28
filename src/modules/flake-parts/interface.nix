{lib, ...}: let
  l = lib // builtins;
  t = l.types;
in {
  options = {
    dream2nix = {
      lib = l.mkOption {
        type = t.raw;
        readOnly = true;
        description = ''
          The system-less dream2nix library.
        '';
      };
      config = l.mkOption {
        type = t.submoduleWith {
          modules = [../config];
        };
        default = {};
        description = ''
          The dream2nix config.
        '';
      };
      projects = l.mkOption {
        type = t.listOf t.raw;
        default = [];
        description = ''
          The projects that outputs will be generated for.
        '';
      };
    };
  };
}
