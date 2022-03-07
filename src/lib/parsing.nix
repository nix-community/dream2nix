{lib, ...}: let
  b = builtins;

  identifyGitUrl = url:
    lib.hasPrefix "git+" url
    || b.match ''^github:.*/.*#.*'' url != null;

  parseGitUrl = url: let
    githubMatch = b.match ''^github:(.*)/(.*)#(.*)$'' url;
  in
    if githubMatch != null
    then let
      owner = b.elemAt githubMatch 0;
      repo = b.elemAt githubMatch 1;
      rev = b.elemAt githubMatch 2;
    in {
      url = "https://github.com/${owner}/${repo}";
      inherit rev;
    }
    else let
      splitUrlRev = lib.splitString "#" url;
      rev = lib.last splitUrlRev;
      urlOnly = lib.head splitUrlRev;
    in
      if lib.hasPrefix "git+ssh://" urlOnly
      then {
        inherit rev;
        url = "https://${(lib.last (lib.splitString "@" url))}";
      }
      else if lib.hasPrefix "git+https://" urlOnly
      then {
        inherit rev;
        url = lib.removePrefix "git+" urlOnly;
      }
      else throw "Cannot parse git url: ${url}";
in {
  inherit identifyGitUrl parseGitUrl;
}
