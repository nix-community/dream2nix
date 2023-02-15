{config, lib, ...}: let
  l = lib // builtins;
  cfg = config.eval-cache;

  packageName =
    if config.name != null
    then config.name
    else config.pname;

  filterTrue = l.filterAttrs (key: val: val == true);

  # TODO: make this recursive
  invalidationData =
    l.intersectAttrs
    (filterTrue cfg.invalidationFields)
    config;

  invalidationHash = l.hashString "sha256"
    # (l.toJSON invalidationData);
    (l.toJSON (invalidationData // cfg.fields));

  # SAVE

  content =
    l.intersectAttrs
    (filterTrue cfg.fields)
    config;
  # content = cfg.content;

  cache = {
    inherit
      content
      invalidationHash
      ;
    # content = mapCachePrio content;
  };

  newFile = config.deps.writeText "cache.json" (l.toJSON cache);

  # LOAD

  file = cfg.repoRoot + cfg.fileRel;

  buildCacheCommand = ''
    To build a new cache file execute:
      cat $(nix-build ${cfg.newFile.drvPath}) > $(git rev-parse --show-toplevel)/${cfg.fileRel}
  '';

  cacheMissingMsg =
    "The cache file ${cfg.fileRel} for drv-parts module '${packageName}' doesn't exist, please create it.";

  cacheMissingError =
    l.trace cacheMissingMsg
    throw ''
      ${cacheMissingMsg}
      ${buildCacheCommand}
    '';

  cacheInvalidMsg =
    "The cache file ${cfg.fileRel} for drv-parts module '${packageName}' is outdated, please update it.";

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

in {

  imports = [
    ./interface.nix
  ];

  config.eval-cache = {
    inherit
      newFile
      ;
  };

  config.eval-cache.content = load file;

  config.passthru.eval-cache = {
    inherit
      newFile
      ;
  };

  config.deps = {nixpkgs, ...}: {
    inherit (nixpkgs) writeText;
  };
}
