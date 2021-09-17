{
  # fetchers
  fetchFromGitHub,
  fetchFromGitLab,
  fetchgit,
  fetchurl,

  lib,
  ...
}:
{
  # sources attrset from generic lock
  sources,
  ...
}:
{
  # attrset: pname -> path of downloaded source
  fetchedSources = lib.mapAttrs (pname: source:
    if source.type == "github" then
      fetchFromGitHub {
        inherit (source) url owner repo rev;
        sha256 = source.hash or null;
      }
    else if source.type == "gitlab" then 
      fetchFromGitLab {
        inherit (source) url owner repo rev;
        sha256 = source.hash or null;
      }
    else if source.type == "git" then
      fetchgit {
        inherit (source) url rev;
        sha256 = source.hash or null;
      }
    else if source.type == "fetchurl" then
      fetchurl {
        inherit (source) url;
        sha256 = source.hash or null;
      }
    else if source.type == "unknown" then
      null
    else throw "unsupported source type '${source.type}'"
  ) sources;
}
