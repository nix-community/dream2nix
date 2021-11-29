{
  lib,

  # dream2nix attributes
  fetchSource,
  fetchers,
  ...
}:
{
  # sources attrset from dream lock
  mainPackageName,
  mainPackageVersion,
  sources,
  ...
}:

let

  b = builtins;

  fetchedSources =

    lib.mapAttrs
      (name: versions:
        lib.mapAttrs
          (version: source:
            if source.type == "unknown" then
              "unknown"
            else if source.type == "path" then
              if lib.isStorePath source.path then
                source.path
              # assume path relative to main package source
              else
                "${fetchedSources."${mainPackageName}"."${mainPackageVersion}"}/${source.path}"
            else if fetchers.fetchers ? "${source.type}" then
              fetchSource { inherit source; sourceVersion = version; }
            else throw "unsupported source type '${source.type}'")
          versions)
      sources;

in
{
  # attrset: pname -> path of downloaded source
  inherit fetchedSources;
}
