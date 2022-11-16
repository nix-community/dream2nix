{config, ...}: let
  l = config.lib // builtins;
in {
  config.dlib = {
    identifyGitUrl = url:
      l.hasPrefix "git+" url
      || l.match ''^github:.*/.*#.*'' url != null;

    parseGitUrl = url: let
      githubMatch = l.match ''^github:(.*)/(.*)#(.*)$'' url;
    in
      if githubMatch != null
      then let
        owner = l.elemAt githubMatch 0;
        repo = l.elemAt githubMatch 1;
        rev = l.elemAt githubMatch 2;
      in {
        url = "https://github.com/${owner}/${repo}";
        inherit rev;
      }
      else let
        splitUrlRev = l.splitString "#" url;
        rev = l.last splitUrlRev;
        urlOnly = l.head splitUrlRev;
      in
        if l.hasPrefix "git+ssh://" urlOnly
        then {
          inherit rev;
          url = "https://${(l.last (l.splitString "@" url))}";
        }
        else if l.hasPrefix "git+https://" urlOnly
        then {
          inherit rev;
          url = l.removePrefix "git+" urlOnly;
        }
        else throw "Cannot parse git url: ${url}";
  };
}
