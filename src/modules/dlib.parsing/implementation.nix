{config, ...}: let
  l = config.lib;

  idToLicenseKey =
    l.mapAttrs'
    (n: v: l.nameValuePair (l.toLower (v.spdxId or v.fullName or n)) n)
    l.licenses;
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

    # Parses a string like "Unlicense OR MIT" to `["unlicense" "mit"]`
    # TODO: this does not parse `AND` or `WITH` or paranthesis, so it is
    # pretty hacky in how it works. But for most cases this should be okay.
    parseSpdxId = _id: let
      # some spdx ids might have paranthesis around them
      id = l.removePrefix "(" (l.removeSuffix ")" _id);
      licenseStrings = l.map l.toLower (l.splitString " OR " id);
      _licenses = l.map (string: idToLicenseKey.${string} or null) licenseStrings;
      licenses = l.filter (license: license != null) _licenses;
    in
      licenses;
  };
}
