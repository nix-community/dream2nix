{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
    modules' = self.modules.dream2nix;
    modules = lib.filterAttrs (name: _: ! lib.elem name excludes) modules';
    dream2nixRoot = ../../../.;
    dream2nix = import dream2nixRoot;
    excludes = [
      # NOT WORKING
      # TODO: fix those
      "core"
      "ui"
      "docs"
      "assertions"
      "nixpkgs-overrides"

      # doesn't need to be rendered
      "_template"
    ];
    public = lib.genAttrs [
      "nodejs-granular-v3"
      "nodejs-package-lock-v3"
      "php-composer-lock"
      "php-granular"
      "pip"
      "rust-cargo-lock"
      "rust-crane"
    ] (name: null);

    # interface
    sourcePathStr = toString dream2nix;
    baseUrl = "https://github.com/nix-community/dream2nix/blob/master";
    specialArgs = {
      inherit dream2nix;
      packageSets.nixpkgs = pkgs;
    };
    transformOptions = opt:
      opt
      // {
        declarations =
          map
          (
            decl: let
              subpath = lib.removePrefix sourcePathStr (toString decl);
            in {
              url = baseUrl + subpath;
              name = "dream2nix" + subpath;
            }
          )
          opt.declarations;
      };
    # 0 = no chapters, 1 = one level of chapters, 2 = two levels of chapters ...
    chaptersNesting = 1;
    # A tree where nodes are (sub)chapters and leafs are options.
    # Nesting can be arbitrary
    chaptersTree = {
      "Modules" =
        lib.filterAttrs (name: _: public ? ${name}) optionsTree;
      "Modules (Internal + Experimental)" =
        lib.filterAttrs (name: _: ! public ? ${name}) optionsTree;
    };
    optionsTree = lib.flip lib.mapAttrs modules (
      name: module: let
        evaluated = lib.evalModules {
          inherit specialArgs;
          modules = [module];
        };
      in
        # lib.trace "Rendering Module ${name}"
        (builtins.removeAttrs evaluated.options ["_module"])
    );

    # implementation
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
    optionsToMdFile = options: let
      docs = pkgs.nixosOptionsDoc {
        inherit options;
        inherit transformOptions;
        warningsAreErrors = false;
      };
    in
      docs.optionsCommonMark;

    mdFiles = nesting: chapters:
      if nesting == 0
      then lib.mapAttrs (name: optionsToMdFile) chapters
      else lib.concatMapAttrs (name: mdFiles (nesting - 1)) chapters;

    mdFilesDir = pkgs.runCommand "md-files-dir" {} ''
      mkdir -p $out
      cp -r ${lib.concatStringsSep "\n cp -r " (lib.mapAttrsToList (name: file: "${file} $out/${name}.md") (mdFiles chaptersNesting chaptersTree))}
    '';

    spacing = depth:
      if depth == 0
      then "- "
      else "  " + spacing (depth - 1);

    # returns "" for chapters with nesting or an md file for chapters with options
    chapterUrl = nesting: name:
      if nesting == 0
      then "options/${name}.md"
      else "";

    renderChapters = depth: nesting: chapters:
      lib.concatStringsSep "\n"
      (lib.flip lib.mapAttrsToList chapters (
        name: chapter:
          "${spacing depth}[${name}](${chapterUrl nesting name})"
          + lib.optionalString (nesting > 0) (renderChapters (depth + 1) (nesting - 1) chapter)
      ));

    summaryMdFile =
      pkgs.writeText "summary.md"
      (renderChapters 0 chaptersNesting chaptersTree);

    mdBookSource = pkgs.runCommand "website-src" {} ''
      mkdir -p $out/options
      cp ${summaryMdFile} $out/SUMMARY.md
      cp -r ${mdFilesDir}/* $out/options/

      # add table of contents for each md file
      for file in $out/options/*.md; do
        name="$(basename "$file")"
        name="''${name%.md}"
        echo "# $name - options" > "$file.tmp"
        echo '<!-- toc -->' | cat - "$file" >> "$file.tmp"
        mv $file.tmp $file
      done
    '';

    website =
      pkgs.runCommand "website" {
        nativeBuildInputs = [
          pkgs.mdbook
          pkgs.mdbook-linkcheck
          # This inserts a table of contents at each '<!-- toc -->'
          inputs.mdbook-toc.defaultPackage.${system}
        ];
      } ''
        cp -rL --no-preserve=mode ${dream2nixRoot}/website/* ./
        cp -r ${mdBookSource}/* src/

        # insert highlight.js
        cp ${highlight-js} ./src/highlight.js
        cp ${highlight-style} ./src/highlight.css

        # merge original and generated SUMMARY.md
        cp ${dream2nixRoot}/website/src/SUMMARY.md SUMMARY.md.orig
        {
          while read ln; do
            case "$ln" in
              "# Modules Reference")
                echo "# Modules Reference"
                cat ${mdBookSource}/SUMMARY.md
                ;;
              *)
                echo "$ln"
                ;;
            esac
          done
        } < SUMMARY.md.orig > src/SUMMARY.md

        # insert icon
        mkdir -p ./theme
        cp ${../../../modules/dream2nix/core/docs/theme/favicon.png} ./theme/favicon.png

        ${pkgs.mdbook}/bin/mdbook build --dest-dir out
        mv out/html $out
      '';
  in {
    packages.website = website;
    packages.docs-generated-mdbook-src = mdBookSource;
  };
}
