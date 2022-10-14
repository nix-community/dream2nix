{
  pkgs,
  lib,
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
  }: let
    b = builtins;
  in {
    calcHash = algo:
      utils.hashPath algo (b.fetchTarball {
        url = "https://github.com/${owner}/${repo}/tarball/${rev}";
      });

    fetched = hash:
      pkgs.fetchFromGitHub {
        inherit owner repo rev hash;
      };
  };
}
