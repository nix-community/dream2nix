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
  allowBuiltinFetchers,
  ...
}:

let
  githubMissingHashErrorText = pname: ''
    Error: Cannot verify the integrity of the source of '${pname}'
    It is a github reference with no hash providedand.
    Solve this problem via any of the wollowing ways:

    - (alternative 1): allow the use of builtin fetchers (which can verify using git rev).
      ```
        dream2nix.buildPackage {
          ...
          allowBuiltinFetchers = true;
          ...
        }
      ```

    - (alternative 2): add a hash to the source via override
      ```
        dream2nix.buildPackage {
          ...
          sourceOverrides = oldSources: {
            "${pname}" = oldSources."${pname}".overrideAttrs (_:{
              hash = "";
            })
          }
          ...
        }
      ```

  '';
in

{
  # attrset: pname -> path of downloaded source
  fetchedSources = lib.mapAttrs (pname: source:
    if source.type == "github" then
      # handle when no hash is provided
      if ! source ? hash then
        if allowBuiltinFetchers then
          builtins.fetchGit {
            inherit (source) rev;
            allRefs = true;
            url = "https://github.com/${source.owner}/${source.repo}";
          }
        else
          throw githubMissingHashErrorText pname
      else
        fetchFromGitHub {
          inherit (source) url owner repo rev;
          hash = source.hash or null;
        }
    else if source.type == "gitlab" then 
      fetchFromGitLab {
        inherit (source) url owner repo rev;
        hash = source.hash or null;
      }
    else if source.type == "git" then
      fetchgit {
        inherit (source) url rev;
        hash = source.hash or null;
      }
    else if source.type == "fetchurl" then
      fetchurl {
        inherit (source) url;
        hash = source.hash or null;
      }
    else if source.type == "unknown" then
      "unknown"
    else throw "unsupported source type '${source.type}'"
  ) sources;
}
