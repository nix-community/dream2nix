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
    lib.listToAttrs
      (lib.flatten
        (lib.mapAttrsToList
          (pname: versions:
            # list of name value pairs
            lib.mapAttrsToList
              (version: source:
                lib.nameValuePair
                  "${pname}#${version}"
                  (if source.type == "unknown" then
                    "unknown"
                  else if source.type == "path" then
                    if lib.isStorePath source.path then
                      source.path
                    # assume path relative to main package source
                    else
                      "${fetchedSources."${mainPackageName}#${mainPackageVersion}"}/${source.path}"
                  else if fetchers.fetchers ? "${source.type}" then
                    fetchSource { inherit source; }
                  else throw "unsupported source type '${source.type}'")
              )
              versions
          )
          sources));

in
{
  # attrset: pname -> path of downloaded source
  inherit fetchedSources;
}
