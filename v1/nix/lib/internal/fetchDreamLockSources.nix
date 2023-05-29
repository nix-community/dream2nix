# This is currently only used for legacy modules ported to v1.
# The dream-lock concept might be deprecated together with this module at some
#   point.
{lib, ...}: let
  l = builtins // lib;

  fetchSource = {
    source,
    extract ? false,
    fetchers,
  }: let
    fetcher = fetchers."${source.type}";
    fetcherArgs = l.removeAttrs source ["dir" "hash" "type"];
    fetcherOutputs = fetcher.outputs fetcherArgs;
    maybeArchive = fetcherOutputs.fetched (source.hash or null);
  in
    if source ? dir
    then "${maybeArchive}/${source.dir}"
    else maybeArchive;

  fetchDreamLockSources = {
    # sources attrset from dream lock
    defaultPackageName,
    defaultPackageVersion,
    sources,
    fetchers,
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
              then "${fetchedSources."${source.rootName}"."${source.rootVersion}"}/${source.path}"
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
              inherit fetchers;
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
    # attrset: pname -> path of downloaded source
  in
    fetchedSources;
in
  fetchDreamLockSources
