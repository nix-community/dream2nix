{
  fetchFromGitHub,
  lib,
  nix,
  runCommand,

  utils,
  # config
  allowBuiltinFetchers,
  ...
}:
{

  inputs = [
    "owner"
    "repo"
    "rev"
  ];

  versionField = "rev";

  defaultUpdater = "githubNewestReleaseTag";

  outputs = { owner, repo, rev, ... }@inp: 
    let
      b = builtins;

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

      calcHash = algo: utils.hashPath algo (b.fetchTarball {
        url = "https://github.com/${owner}/${repo}/tarball/${rev}";
      });

      fetched = hash:
        if hash == null then
          b.trace "using fetchGit" 
          (if allowBuiltinFetchers then
            builtins.fetchGit {
              inherit rev;
              allRefs = true;
              url = "https://github.com/${owner}/${repo}";
            }
          else
            throw githubMissingHashErrorText (inp.pname or repo))
        else
          b.trace "using fetchFromGithub"
          fetchFromGitHub {
            inherit owner repo rev hash;
          };

    };
}