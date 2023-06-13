{
  config,
  lib,
  dream2nix,
  packageSets,
  system,
  ...
}: let
  l = lib // builtins;
  floco = (import "${dream2nix.inputs.floco.outPath}/flake.nix").outputs {inherit (packageSets) nixpkgs;};
  cfg = config.nodejs-floco;
in {
  imports = [
    dream2nix.modules.drv-parts.mkDerivation
    ./interface.nix
    ../lock
  ];

  config = {
    deps = {
      nixpkgs,
      writers,
      ...
    }:
      l.mapAttrs (_: l.mkDefault) {
        inherit (nixpkgs) coreutils jq;
        inherit (writers) writePureShellScript;
      };

    lock.fields.floco = {
      script =
        config.deps.writePureShellScript [config.deps.nix config.deps.jq config.deps.coreutils]
        ''
          pdefs=''${TMPDIR:-/tmp/}floco.XXXXX
          nix run github:aakropotkin/floco#floco translate -- -ptjo $pdefs ${cfg.source}
          jq .floco $pdefs > $out
          rm $pdefs
        '';
    };

    nodejs-floco.drv = floco.lib.evalModules {
      modules =
        [
          floco.nixosModules.default
          {config = {inherit (config.lock.content) floco;};}
          {floco.settings.system = system;}
        ]
        ++ cfg.modules;
    };
  };
}
