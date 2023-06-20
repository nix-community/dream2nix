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

  fmod = floco.lib.evalModules {
    modules =
      [
        floco.nixosModules.default
        {config = {inherit (config.lock.content) floco;};}
        {
          floco.settings = {
            system = system;
          };
          floco.pdefs.${flocoName}.${flocoVersion}.fetchInfo = l.mkForce {
            path = "${cfg.source}";
          };
        }
      ]
      ++ cfg.modules;
  };

  packageJson = l.fromJSON (l.readFile "${cfg.source}/package.json");

  flocoName = packageJson.name or config.name;
  flocoVersion = packageJson.version or config.version;
in {
  imports = [
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
        inherit (nixpkgs) coreutils git jq openssh;
        inherit (writers) writePureShellScript;
      };

    lock.fields.floco = {
      script =
        config.deps.writePureShellScript
        [
          config.deps.coreutils
          config.deps.git
          config.deps.jq
          config.deps.nix
          config.deps.openssh
        ]
        ''
          cd $TMPDIR
          cp -r ${cfg.source}/* .
          chmod +w -R .
          nix run github:aakropotkin/floco -- translate -ptj
          jq .floco ./pdefs.json > $out
        '';
    };

    public =
      fmod.config.floco.packages.${config.name}.${config.version}.global
      // {inherit config;};
  };
}
