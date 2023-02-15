{config, lib, ...}: let
  l = lib // builtins;
  cfg = config.eval-cache;

  packageName =
    if config.name != null
    then config.name
    else config.pname;

  filterTrue = l.filterAttrs (key: val: val == true);

  invalidationFields = (filterTrue cfg.invalidationFields);

  # TODO: make this recursive
  invalidationData = l.intersectAttrs invalidationFields config;

  invalidationHash = l.hashString "sha256"
    # (l.toJSON invalidationData);
    (l.toJSON (invalidationData // cfg.fields));

  fields = filterTrue cfg.fields;

  # SAVE

  content = l.intersectAttrs fields config;

  cache = {
    inherit
      content
      invalidationHash
      ;
    # content = mapCachePrio content;
  };

  newFile = config.deps.writeText "cache.json" (l.toJSON cache);

  # LOAD

  file = cfg.repoRoot + cfg.cacheFileRel;

  buildCacheCommand = ''
    To build a new cache file execute:
      cat $(nix-build ${cfg.newFile.drvPath}) > $(git rev-parse --show-toplevel)/${cfg.cacheFileRel}
  '';

  cacheMissingMsg =
    "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' doesn't exist, please create it.";

  cacheMissingError =
    l.trace cacheMissingMsg
    throw ''
      ${cacheMissingMsg}
      ${buildCacheCommand}
    '';

  cacheInvalidMsg =
    "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' is outdated, please update it.";

  cacheInvalidError =
    l.trace cacheInvalidMsg
    throw ''
      ${cacheInvalidMsg}
      ${buildCacheCommand}
    '';

  cachePrio = l.modules.defaultOverridePriority + 1;

  mapCachePrio = l.mapAttrs (key: val: l.mkOverride cachePrio val);

  load = file: let
    cache = l.fromJSON (l.readFile file);
    attrs = cache.content;
    isValid = cache.invalidationHash == invalidationHash;
  in
    if ! l.pathExists file
    then cacheMissingError
    else if ! isValid
    then cacheInvalidError
    else mapCachePrio attrs;

  configIfEnabled = l.mkIf (cfg.enable) {
    eval-cache = {
      inherit
        newFile
        ;
    };

    eval-cache.content = load file;

    passthru.eval-cache = {
      inherit
        newFile
        ;
    };

    deps = {nixpkgs, ...}: {
      inherit (nixpkgs) writeText;
    };
  };

  configIfDisabled = l.mkIf (! cfg.enable) {
    eval-cache.content = content;
  };

in {

  imports = [
    ./interface.nix
  ];

  config = l.mkMerge [configIfEnabled configIfDisabled];

}
