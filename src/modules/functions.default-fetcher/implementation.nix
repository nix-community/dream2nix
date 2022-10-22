{config, ...}: let
  inherit (config) lib;

  fetchers = config.fetchers;
  fetchSource = config.functions.fetchers.fetchSource;
  func = {
    # sources attrset from dream lock
    defaultPackage,
    defaultPackageVersion,
    sourceOverrides,
    sources,
    sourceRoot ? null,
    ...
  }: let
    l = lib // builtins;

    fetchedSources =
      l.mapAttrs
      (name: versions:
        l.mapAttrs
        (version: source:
          if source.type == "unknown"
          then "unknown"
          else if source.type == "path"
          then let
            path =
              if l.isStorePath (l.concatStringsSep "/" (l.take 4 (l.splitString "/" source.path)))
              then source.path
              else if name == source.rootName && version == source.rootVersion
              then throw "source for ${name}@${version} is referencing itself"
              else if source.rootName != null && source.rootVersion != null
              then "${overriddenSources."${source.rootName}"."${source.rootVersion}"}/${source.path}"
              else if sourceRoot != null
              then "${sourceRoot}/${source.path}"
              else throw "${name}-${version}: cannot determine path source";
          in
            l.path {
              inherit path;
              name = l.strings.sanitizeDerivationName "${name}-${version}-source";
            }
          else if fetchers ? "${source.type}"
          then
            fetchSource {
              source =
                source
                // {
                  pname = source.pname or name;
                  version = source.version or version;
                };
            }
          else throw "unsupported source type '${source.type}'")
        versions)
      sources;

    overriddenSources =
      l.zipAttrsWith
      (name: versionsSets:
        l.zipAttrsWith
        (version: sources: l.last sources)
        versionsSets)
      [
        fetchedSources
        (sourceOverrides fetchedSources)
      ];
  in {
    # attrset: pname -> path of downloaded source
    fetchedSources = overriddenSources;
  };
in {
  config = {
    functions.defaultFetcher = func;
  };
}
