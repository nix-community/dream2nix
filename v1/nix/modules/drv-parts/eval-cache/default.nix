{
  config,
  lib,
  ...
}: let
  l = lib // builtins;
  cfg = config.eval-cache;

  packageName = config.public.name;

  filterTrue = l.filterAttrsRecursive (key: val: l.isAttrs val || val == true);

  invalidationFields = filterTrue cfg.invalidationFields;

  intersectAttrsRecursive = a: b:
    l.mapAttrs
    (
      key: valB:
        if l.isAttrs valB && l.isAttrs a.${key}
        then intersectAttrsRecursive a.${key} valB
        else valB
    )
    (l.intersectAttrs a b);

  invalidationData = intersectAttrsRecursive invalidationFields config;

  invalidationHash =
    l.hashString "sha256"
    (l.toJSON [invalidationData cfg.fields]);

  fields = filterTrue cfg.fields;

  # SAVE

  currentContent = intersectAttrsRecursive fields config;

  newCache = {
    inherit invalidationHash;
    content = currentContent;
  };

  newFile' = config.deps.writeText "cache.json" (l.toJSON newCache);
  newFile = config.deps.runCommand "cache.json" {} ''
    cat ${newFile'} | ${config.deps.jq}/bin/jq > $out
  '';

  # LOAD

  file = cfg.repoRoot + cfg.cacheFileRel;

  refreshCommand =
    l.unsafeDiscardStringContext
    "cat $(nix-build ${cfg.newFile.drvPath} --no-link) > $(git rev-parse --show-toplevel)/${cfg.cacheFileRel}";

  newFileMsg = "To generate a new cache file, execute:\n  ${refreshCommand}";

  ifdInfoMsg = "Information on how to fix this is shown below if evaluated with `--allow-import-from-derivation`";

  cacheMissingMsg = "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' doesn't exist, please create it.";

  cacheMissingError =
    l.trace ''
      ${"\n"}
      ${cacheMissingMsg}
      ${ifdInfoMsg}
    ''
    l.trace ''
      ${"\n"}
      ${newFileMsg}
    '';

  cacheInvalidMsg = "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' is outdated, please update it.";

  cacheInvalidError =
    l.trace ''
      ${"\n"}
      ${cacheInvalidMsg}
      ${ifdInfoMsg}
    ''
    l.trace ''
      ${"\n"}
      ${newFileMsg}
    '';

  cachePrio = l.modules.defaultPriority + 1;

  mapCachePrio = l.mapAttrs (key: val: l.mkOverride cachePrio val);

  cache = l.fromJSON (l.readFile file);
  cacheFileExists = l.pathExists file;
  cacheFileValid = cache.invalidationHash == invalidationHash;

  # Return either the content from cache.json, or if it's invalid or missing,
  #   use the content without going through the cache.
  loadedContent =
    if ! cacheFileExists
    then cacheMissingError currentContent
    else if ! cacheFileValid
    then cacheInvalidError currentContent
    else mapCachePrio cache.content;

  configIfEnabled = l.mkIf (cfg.enable) {
    eval-cache = {
      inherit
        newFile
        ;
      refresh =
        config.deps.writeScript
        "refresh-${config.public.name}"
        refreshCommand;
    };

    eval-cache.content = loadedContent;

    deps = {nixpkgs, ...}: {
      inherit
        (nixpkgs)
        jq
        runCommand
        writeText
        writeScript
        ;
    };
  };

  configIfDisabled = l.mkIf (! cfg.enable) {
    eval-cache.content = currentContent;
  };
in {
  imports = [
    ./interface.nix
  ];

  config = l.mkMerge [configIfEnabled configIfDisabled];
}
