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
    dream2nixRoot = ../../../.;
    dream2nix = import dream2nixRoot;
    baseUrl = "https://github.com/nix-community/dream2nix/blob/master";

    getOptions = {modules}: let
      options = lib.flip lib.mapAttrs modules (
        name: module: let
          evaluated = lib.evalModules {
            specialArgs = {
              inherit dream2nix;
              packageSets.nixpkgs = pkgs;
            };
            modules = [module];
          };
        in
          evaluated.options
      );
      docs = lib.flip lib.mapAttrs options (name: options:
        pkgs.nixosOptionsDoc {
          inherit options;
          inherit transformOptions;
          warningsAreErrors = false;
        });
    in {
      inherit options docs;
    };

    transformOptions = opt:
      opt
      // {
        declarations =
          map
          (
            decl: let
              subpath = lib.removePrefix (toString dream2nix) (toString decl);
            in {
              url = baseUrl + subpath;
              name = "dream2nix" + subpath;
            }
          )
          opt.declarations;
      };

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

    options = getOptions {
      inherit modules;
    };

    referenceDocs = let
      publicModules =
        lib.filterAttrs
        (n: v: lib.pathExists (v + "/README.md"))
        modules;
      createReference = name: sourcePath: ''
        target_dir="$out/${name}/"
        mkdir -p "$target_dir"
        ln -s ${sourcePath}/README.md "$target_dir/index.md"
        ln -s ${options.docs.${name}.optionsJSON}/share/doc/nixos/options.json "$target_dir"
      '';
    in
      pkgs.runCommand "reference" {
      } ''
        ${lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs createReference publicModules))}
      '';

    website =
      pkgs.runCommand "website" {
        nativeBuildInputs = [
          pkgs.python3.pkgs.mkdocs
          pkgs.python3.pkgs.mkdocs-material
          referenceDocs
        ];
      } ''
        cp -rL --no-preserve=mode  ${dream2nixRoot}/docs/* .
        ln -s ${referenceDocs} ./src/reference
        mkdocs build
      '';
  in {
    packages.reference = referenceDocs;
    packages.website = website;
    devShells.mkdocs = let
      pythonWithDeps = pkgs.python3.withPackages (
        ps: [
          self.packages.${system}.mkdocs
          self.packages.${system}.mkdocs-material
          ps.ipython
          ps.black
          ps.pytest
          ps.pytest-cov
        ]
      );
    in
      pkgs.mkShell {
        packages = [
          pythonWithDeps
        ];
      };
  };
}
