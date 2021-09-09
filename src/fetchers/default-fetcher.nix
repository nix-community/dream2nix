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
}:
lib.mapAttrs (pname: source:
  if source.type == "github" then
    fetchFromGitHub {
      inherit (source) url owner repo rev;
      sha256 = source.hash;
    }
  else if source.type == "gitlab" then 
    fetchFromGitLab {
      inherit (source) url owner repo rev;
      sha256 = source.hash;
    }
  else if source.type == "git" then
    fetchgit {
      inherit (source) url rev;
      sha256 = source.hash;
    }
  else if source.type == "fetchurl" then
    fetchurl {
      inherit (source) url;
      sha256 = source.hash;
    }
  else throw "unsupported source type '${source.type}'"
) sources
