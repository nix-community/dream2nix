{
  lib,
  pkgs,
  ...
}: let
  l = lib // builtins;
in {
  "phpstan/phpstan-phpunit" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "phpstan/phpstan-symfony" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "phpstan/phpstan-deprecation-rules" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "phpstan/phpstan-strict-rules" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "rector/rector-phpstan-rules" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "danielstjules/stringy" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
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
  "phpunit/phpunit" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\" = {}" \
          composer.json | sponge composer.json
      '';
    };
  };
  "phpunit/php-invoker" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/code-unit" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\" = {}" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/diff" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/object-reflector" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/type" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/global-state" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/object-enumerator" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
  "sebastian/comparator" = {
    fix-autoload-dev = {
      postPatch = ''
        jq ".\"autoload-dev\".classmap = []" \
          composer.json | sponge composer.json
      '';
    };
  };
}
