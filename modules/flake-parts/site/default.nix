{
  inputs,
  self,
  ...
}: {
  perSystem = {
    config,
    self',
    inputs',
    pkgs,
    lib,
    ...
  }: {
    /*
    Check the links, including anchors (not currently supported by mdbook)

    Putting this in a separate check has the benefits that
     - output can always be inspect with browser
     - this slow check (1 minute) is not part of the iteration cycle

    Ideally https://github.com/linkchecker/linkchecker/pull/661 is merged
    upstream, so that it's quick and can run often without blocking the
    iteration cycle unnecessarily.
    */
    # checks.linkcheck =
    #   pkgs.runCommand "linkcheck"
    #   {
    #     nativeBuildInputs = [pkgs.linkchecker pkgs.python3];
    #     site = config.packages.website;
    #   } ''
    #     # https://linkchecker.github.io/linkchecker/man/linkcheckerrc.html
    #     cat >>$TMPDIR/linkcheckrc <<EOF
    #     [checking]
    #     threads=100

    #     [AnchorCheck]

    #     EOF

    #     echo Checking $site
    #     linkchecker -f $TMPDIR/linkcheckrc $site/

    #     touch $out
    #   '';

    packages = {
      highlight-js = let
        highlight-core = pkgs.fetchurl {
          url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js";
          hash = "sha256-g3pvpbDHNrUrveKythkPMF2j/J7UFoHbUyFQcFe1yEY=";
        };
        highlight-nix = pkgs.fetchurl {
          url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/nix.min.js";
          hash = "sha256-BLoZ+/OroDAxMsdZ4GFZtQfsg6ZJeLVNeBzN/82dYgk=";
        };
      in
        pkgs.runCommand "highlight-js" {} ''
          cat ${highlight-core} > $out
          cat ${highlight-nix} >> $out
        '';
      highlight-style = pkgs.fetchurl {
        url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/vs.min.css";
        hash = "sha256-E1kfafj5iO+Tw/04hxdSG+OnvczojOXK2K0iCEYfzSw=";
      };
      website = pkgs.stdenvNoCC.mkDerivation {
        name = "website";
        nativeBuildInputs = [pkgs.mdbook pkgs.mdbook-linkcheck];
        src = ./.;
        buildPhase = ''
          runHook preBuild

          rm ./src/intro.md
          cp ${../../../README.md} ./src/intro.md

          # insert highlight.js
          cp ${self'.packages.highlight-js} ./src/highlight.js
          cp ${self'.packages.highlight-style} ./src/highlight.css


          # insert the generated part of the summary into the origin SUMMARY.md
          cp ./src/SUMMARY.md SUMMARY.md.orig
          {
            while read ln; do
              case "$ln" in
                "# Modules Reference")
                  echo "# Modules Reference"
                  cat ${config.generated-docs.generated-summary-md}
                  ;;
                *)
                  echo "$ln"
                  ;;
              esac
            done
          } < SUMMARY.md.orig > src/SUMMARY.md

          mkdir -p ./theme
          cp ${../../dream2nix/core/docs/theme/favicon.png} ./theme/favicon.png

          mkdir -p src/options
          for f in ${config.generated-docs.generated-docs}/*.html; do
            cp "$f" "src/options/$(basename "$f" .html).md"
          done
          mdbook build --dest-dir $TMPDIR/out
          cp -r $TMPDIR/out/html $out
          cp _redirects $out

          # TODO: point to something else than public.html
          echo '<html><head><script>window.location.pathname = window.location.pathname.replace(/options.html$/, "") + "options/public.html"</script></head><body><a href="options/public.html">to the options</a></body></html>' \
            >$out/options.html

          runHook postBuild
        '';
        dontInstall = true;
      };
    };
  };
}
