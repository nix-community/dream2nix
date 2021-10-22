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
  ...
}:

{
  # attrset: pname -> path of downloaded source
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
                  else if fetchers.fetchers ? "${source.type}" then
                    fetchSource { inherit source; }
                  else throw "unsupported source type '${source.type}'")
              )
              versions
          )
          sources))
  ;
}
