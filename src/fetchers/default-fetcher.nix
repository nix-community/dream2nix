{
  lib,

  # dream2nix attributes
  fetchSource,
  fetchers,
  ...
}:
{
  # sources attrset from generic lock
  sources,
  allowBuiltinFetchers,
  ...
}:

{
  # attrset: pname -> path of downloaded source
  fetchedSources = lib.mapAttrs (pname: source:
    if source.type == "unknown" then
      "unknown"
    else if fetchers.fetchers ? "${source.type}" then
      fetchSource { inherit source; }
    else throw "unsupported source type '${source.type}'"
  ) sources;
}
