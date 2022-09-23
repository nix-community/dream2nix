{
  lib,
  pkgs,
  ...
}: let
  l = lib // builtins;
in {
  "components/jquery" = {
    fix-authors = {
      nativeBuildInputs = orig: orig ++ (with pkgs; [moreutils]);
      postPatch = ''
        jq \
          ".authors |= map(with_entries(
             if   .key == \"url\" \
             then .key =  \"homepage\" \
             else . end \
          ))" \
          composer.json | sponge composer.json
      '';
    };
  };
}
