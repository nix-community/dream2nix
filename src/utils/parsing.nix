{
  lib,
  ...
}:
let

  b = builtins;

  identifyGitUrl = url:
    lib.hasPrefix "git+" url;

  parseGitUrl = url:
    let
      splitUrlRev = lib.splitString "#" url;
      rev = lib.last splitUrlRev;
      urlOnly = lib.head splitUrlRev;
    in
      if lib.hasPrefix "git+ssh://" urlOnly then
        {
          inherit rev;
          url = "https://${(lib.last (lib.splitString "@" url))}";
        }
      else if lib.hasPrefix "git+https://" urlOnly then
        {
          inherit rev;
          url = lib.removePrefix "git+" urlOnly;
        }
      else
        throw "Cannot parse git url: ${url}";


in
{
  inherit identifyGitUrl parseGitUrl;
}
