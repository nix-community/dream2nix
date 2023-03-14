{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.lock;

  packageName = config.public.name;

  intersectAttrsRecursive = a: b:
    l.mapAttrs
    (
      key: valB:
        if l.isAttrs valB && l.isAttrs a.${key}
        then intersectAttrsRecursive a.${key} valB
        else valB
    )
    (l.intersectAttrs a b);

  # LOAD
  file = cfg.repoRoot + cfg.lockFileRel;
  data = l.fromJSON (l.readFile file);
  fileExist = l.pathExists file;

  refreshOne = path': script: let
    path = path';
  in
    config.deps.writeScript "refresh-${packageName}" ''
      export out=$TMPDIR/${l.concatStringsSep "." path}
      ${script}
      ${config.deps.jq}/bin/jq -n --argjson path '${l.toJSON path}' --argfile data "$out" '{} | setpath($path; $data)' > "$out.tmp"
      mv "$out.tmp" "$out"
    '';

  fieldsAsScripts =
    l.mapAttrsRecursiveCond
    (val: ! l.isDerivation val)
    refreshOne
    config.lock.fields;

  allScripts = l.collect l.isDerivation fieldsAsScripts;

  refresh = config.deps.writeScriptBin "refresh-${packageName}" ''
    export TMPDIR=$(mktemp -d)
    export out=$(git rev-parse --show-toplevel)/${cfg.lockFileRel}
    ${l.concatStringsSep "\n" allScripts}
    jq -s 'reduce .[] as $x ({}; . * $x)' $TMPDIR/* > $out
  '';

  missingError = ''
    The lock file ${cfg.lockFileRel} for drv-parts module '${packageName}' is missing, please update it.
    To create the lock file, execute:\n  ${config.lock.refresh}
  '';

  loadedContent =
    if ! fileExist
    then throw missingError
    else data;
in {
  imports = [
    ./interface.nix
  ];

  config = {
    lock.refresh = refresh;

    lock.content = loadedContent;

    deps = {nixpkgs, ...}:
      l.mapAttrs (_: l.mkDefault) {
        inherit (nixpkgs) nix;
        inherit (nixpkgs) writeScriptBin;
      };
  };
}
