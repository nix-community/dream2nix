{
  lib,

  # dream2nix
  utils,
}:

let
  b = builtins;

  testParseGitUrl =
    let
      testCases = [
        {
          input = "git+ssh://git@github.com/mattermost/marked.git#6ca9a6b3f4bdd35dbf58d06f5e53369791e05915";
          output = { owner = "mattermost"; repo = "marked"; rev = "6ca9a6b3f4bdd35dbf58d06f5e53369791e05915"; };
        }
        {
          input = "git+https://gitlab.com/openengiadina/js-eris.git#cbe42c8d1921837cc1780253dc9113622cd0826a";
          output = { owner = "openengiadina"; repo = "js-eris"; rev = "cbe42c8d1921837cc1780253dc9113622cd0826a"; };
        }
      ];

in
assert ! testParseGithu ->
  throw "failed";
true
