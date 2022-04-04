{
  lib,
  # dream2nix attributes
  fetchSource,
  fetchers,
  ...
}: {
  # sources attrset from dream lock
  defaultPackage,
  defaultPackageVersion,
  sourceOverrides,
  sources,
  ...
}: let
  b = builtins;

  fetchedSources =
    lib.mapAttrs
    (name: versions:
      lib.mapAttrs
      (version: source:
        if source.type == "unknown"
        then "unknown"
        else if source.type == "path"
        then
          if lib.isStorePath source.path
          then source.path
          else if name == source.rootName && version == source.rootVersion
          then throw "source for ${name}@${version} is referencing itself"
          else "${overriddenSources."${source.rootName}"."${source.rootVersion}"}/${source.path}"
        else if fetchers.fetchers ? "${source.type}"
        then
          fetchSource {
            source =
              source
              // {
                pname = name;
                inherit version;
              };
          }
        else throw "unsupported source type '${source.type}'")
      versions)
    sources;

  overriddenSources =
    lib.recursiveUpdateUntil
    (path: l: r: lib.isDerivation l)
    fetchedSources
    (sourceOverrides fetchedSources);
in {
  # attrset: pname -> path of downloaded source
  fetchedSources = overriddenSources;
}
