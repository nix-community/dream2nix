{
  curl,
  gnugrep,
  jq,
  lib,
  python3,
  writeText,
  # dream2nix inputs
  utils,
  ...
}: {
  githubNewestReleaseTag = {
    owner,
    repo,
    ...
  }:
    utils.writePureShellScript [curl jq] ''
      curl -s "https://api.github.com/repos/${owner}/${repo}/releases?per_page=1" | jq -r '.[0].tag_name'
    '';

  pypiNewestReleaseVersion = {pname, ...}:
    utils.writePureShellScript [curl jq] ''
      curl -s https://pypi.org/pypi/${pname}/json | jq -r '.info.version'
    '';

  npmNewestReleaseVersion = {pname, ...}:
  # api docs: https://github.com/npm/registry/blob/master/docs/REGISTRY-API.md#get
    utils.writePureShellScript [curl jq] ''
      curl -s https://registry.npmjs.com/${pname} | jq -r '."dist-tags".latest'
    '';

  urlRegexPython =
    # Don't forget to use double quoted strings
    #   or double escape ('\\' instead of '\').
    # Expects named group 'rev' to be defined.
    # Example regex:
    #   ''[Pp]ython-(?P<ver>[\d\.]+)\.tgz''
    {
      url,
      regex,
      ...
    }: let
      reFile = writeText "regex" regex;
    in
      utils.writePureShellScript [curl gnugrep python3] ''
        curl -s ${url} \
        | python3 -c \
          'import re, sys; print(re.search(open("${reFile}").read(), sys.stdin.read()).group("ver"), end="")'
      '';
}
