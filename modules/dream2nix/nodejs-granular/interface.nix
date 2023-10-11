{
  config,
  lib,
  dream2nix,
  packageSets,
  ...
}: let
  l = lib // builtins;
  t = l.types;
in {
  options.nodejs-granular = l.mapAttrs (_: l.mkOption) {
    buildScript = {
      type = t.nullOr (t.oneOf [t.str t.path t.package]);
      description = ''
        A command or script to execute instead of `npm run build`.
        Is only executed if `runBuild = true`.
      '';
    };
    installMethod = {
      type = t.enum [
        "symlink"
        "copy"
      ];
      description = ''
        Strategy to use for populating ./node_modules.
        Symlinking is quicker, but often introduces compatibility issues with bundlers like webpack and other build tools.
        Copying is slow, but more reliable;
      '';
    };
    runBuild = {
      type = t.bool;
      description = ''
        Whether to run a package's build script (aka. `npm run build`)
      '';
    };
    deps = {
      type = t.lazyAttrsOf (t.lazyAttrsOf (t.submodule {
        imports = [
          dream2nix.modules.dream2nix.core
          dream2nix.modules.dream2nix.mkDerivation
        ];
        _module.args = {inherit dream2nix packageSets;};
      }));
    };
  };
}
