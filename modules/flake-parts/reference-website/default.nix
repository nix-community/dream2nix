{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    self',
    ...
  }: let
    inherit (import ./frontmatter.nix {inherit lib;}) getFrontmatterString;

    dream2nixRoot = ../../../.;
    dream2nix = import dream2nixRoot;

    modules =
      lib.filterAttrs (
        name: _:
          ! lib.elem name
          [
            # NOT WORKING
            # TODO: fix those
            "core"
            "ui"
            "docs"
            "assertions"
            "nixpkgs-overrides"
            # doesn't need to be rendered
            "_template"
          ]
      )
      dream2nix.modules.dream2nix;

    state = name: path: let
      frontmatter = getFrontmatterString path name;
    in
      if lib.hasInfix ''state: "internal"'' frontmatter
      then "internal"
      else if lib.hasInfix ''state: "experimental"'' frontmatter
      then "experimental"
      else "released";

    doDisplay = name: path: lib.pathExists (path + "/README.md");

    displayedModules = lib.filterAttrs doDisplay modules;

    moduleStates =
      lib.mapAttrs (
        name: path: state name path
      )
      displayedModules;

    releaseModules =
      lib.filterAttrs (
        name: _: moduleStates.${name} == "released"
      )
      displayedModules;

    internalModules =
      lib.filterAttrs (
        name: _: moduleStates.${name} == "internal"
      )
      displayedModules;

    experimentalModules =
      lib.filterAttrs (
        name: _: moduleStates.${name} == "experimental"
      )
      displayedModules;

    optionsReference = modules: let
      linkOptionsDocs = name: sourcePath: ''
        [Browse Options](/options/?scope=${name})
      '';

      createReference = name: sourcePath: ''
        cat ${sourcePath}/README.md > "$out/${name}.md"
        echo -e '\n\n👉 ${linkOptionsDocs name sourcePath}' >> "$out/${name}.md"
      '';
    in
      pkgs.runCommand "reference" {
      }
      ''
        mkdir "$out"
        ${lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs createReference modules))}
      '';

    website =
      pkgs.runCommand "website" {
        nativeBuildInputs = [
          pkgs.python3.pkgs.mkdocs
          pkgs.python3.pkgs.mkdocs-material
          pkgs.python3.pkgs.mkdocs-awesome-nav
        ];
      } ''
        cp -rL --no-preserve=mode  ${dream2nixRoot}/docs/* .
        ln -sfT ${optionsReference releaseModules} ./src/reference
        ln -sfT ${optionsReference internalModules} ./src/reference-\(internal\)
        ln -sfT ${optionsReference experimentalModules} ./src/reference-\(experimental\)
        mkdocs build
        echo -n "dream2nix.dev" > $out/CNAME
        cp -r ${self'.packages.website-options} $out/options
      '';
  in {
    packages.website = website;
    devShells.website = let
      pythonWithDeps = pkgs.python3.withPackages (
        ps: [
          ps.ipython
          ps.black
          ps.pytest
          ps.pytest-cov
        ]
      );
    in
      pkgs.mkShell {
        inputsFrom = [self.packages.${system}.website];
        packages = [
          pythonWithDeps
        ];

        shellHook = ''
          cd $PRJ_ROOT/docs
          if [ ! -d src/reference ]; then
            echo "linking .#optionsReference to src/reference, you need to update this manually\
            and remove it before a production build"
            ln -sfT $(nix build .#optionsReference --no-link --print-out-paths) src/reference
          fi
        '';
      };
  };
}
