{
  fetchFromGitHub,
  lib,
  nix,
  runCommand,
  utils,
  ...
}: {
  inputs = [
    "owner"
    "repo"
    "rev"
  ];

  versionField = "rev";

  defaultUpdater = "githubNewestReleaseTag";

  outputs = {
    owner,
    repo,
    rev,
    ...
  } @ inp: let
    b = builtins;
  in {
    calcHash = algo:
      utils.hashPath algo (b.fetchTarball {
        url = "https://github.com/${owner}/${repo}/tarball/${rev}";
      });

    fetched = hash:
      fetchFromGitHub {
        inherit owner repo rev hash;
      };
  };
}
