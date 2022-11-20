{
  pkgs,
  utils,
  ...
}:
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
  reFile = pkgs.writeText "regex" regex;
in
  utils.writePureShellScript (with pkgs; [curl gnugrep python3]) ''
    curl -s ${url} \
    | python3 -c \
      'import re, sys; print(re.search(open("${reFile}").read(), sys.stdin.read()).group("ver"), end="")'
  ''
