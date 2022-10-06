{
  pkgs,
  utils,
  ...
}: {
  inputs = [
    "owner"
    "repo"
    "rev"
  ];

  versionField = "rev";

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
        url = "https://gitlab.com/${owner}/${repo}/-/archive/${rev}/${repo}-${rev}.tar.gz";
      });

    fetched = hash:
      pkgs.fetchFromGitLab {
        inherit owner repo rev hash;
      };
  };
}
