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
          # assume path relative to main package source
          else "${overriddenSources."${defaultPackage}"."${defaultPackageVersion}"}/${source.path}"
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
    lib.recursiveUpdate
    fetchedSources
    (sourceOverrides fetchedSources);
in {
  # attrset: pname -> path of downloaded source
  fetchedSources = overriddenSources;
}
