{
  lib,
  pkgs,
  ...
}: let
  l = lib // builtins;
in {
  "rector/rector" = {
    skip-composer-install = {
      dontConfigure = true;
      dontBuild = true;
    };
  };
  "components/jquery" = {
    fix-authors = {
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
