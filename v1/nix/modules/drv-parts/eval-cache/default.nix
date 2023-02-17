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
    (l.toJSON (invalidationData // cfg.fields));

  fields = filterTrue cfg.fields;

  # SAVE

  content = l.intersectAttrs fields config;

  cache-content = {
    inherit
      content
      invalidationHash
      ;
  };

  newFile' = config.deps.writeText "cache.json" (l.toJSON cache-content);
  newFile = config.deps.runCommand "cache.json" {} ''
    cat ${newFile'} | ${config.deps.jq}/bin/jq > $out
  '';

  # LOAD

  file = cfg.repoRoot + cfg.cacheFileRel;

  refreshCommand =
    "cat ${cfg.newFile} > $(git rev-parse --show-toplevel)/${cfg.cacheFileRel}";

  newFileMsg = "To generate a new cache file, execute:\n  ${refreshCommand}";

  ifdInfoMsg =
    "Information on how to fix this is shown below if evaluated with `--allow-import-from-derivation`";

  cacheMissingMsg =
    "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' doesn't exist, please create it.";

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

  cacheInvalidMsg =
    "The cache file ${cfg.cacheFileRel} for drv-parts module '${packageName}' is outdated, please update it.";

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

  cachePrio = l.modules.defaultOverridePriority + 1;

  mapCachePrio = l.mapAttrs (key: val: l.mkOverride cachePrio val);

  cache = l.fromJSON (l.readFile file);
  cacheFileExists = l.pathExists file;
  cacheFileValid = cache.invalidationHash == invalidationHash;

  # Return either the content from cache.json, or if it's invalid or missing,
  #   use the content without going through the cache.
  loadedContent =
    if ! cacheFileExists
    then cacheMissingError content
    else if ! cacheFileValid
    then cacheInvalidError content
    else mapCachePrio cache.content;

  configIfEnabled = l.mkIf (cfg.enable) {
    eval-cache = {
      inherit
        newFile
        ;
    };

    eval-cache.content = loadedContent;

    passthru.eval-cache = {
      inherit
        newFile
        ;
      refresh = refreshCommand;
    };

    deps = {nixpkgs, ...}: {
      inherit (nixpkgs)
        jq
        runCommand
        writeText
        ;
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
