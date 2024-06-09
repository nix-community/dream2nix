# An example package with dependencies defined via pyproject.toml
{
  config,
  lib,
  dream2nix,
  ...
}: let
  pyproject = lib.importTOML (config.mkDerivation.src + /pyproject.toml);
in {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python3;
  };

  inherit (pyproject.project) name version;

  mkDerivation = {
    src = lib.cleanSourceWith {
      src = lib.cleanSource ./.;
      filter = name: type:
        !(builtins.any (x: x) [
          (lib.hasSuffix ".nix" name)
          (lib.hasPrefix "." (builtins.baseNameOf name))
          (lib.hasSuffix "flake.lock" name)
        ]);
    };
  };

  buildPythonPackage = {
    format = lib.mkForce "pyproject";
    pythonImportsCheck = [
      "mytool"
    ];
  };

  pip = {
    # Setting editables.$pkg.null will link the current project root as an editable
    # for the root package (my-tool here), or otherwise copy the contents of mkDerivation.src
    # to .dream2nix/editables to make them writeable.
    # Alternatively you can point it to an existing checkout via an absolute path, i.e.:
    #   editables.charset-normalizer = "/home/my-user/src/charset-normalizer";
    editables.charset-normalizer = ".editables/charset_normalizer";

    requirementsList =
      pyproject.build-system.requires
      or []
      ++ pyproject.project.dependencies;
    flattenDependencies = true;

    overrides.click.mkDerivation.nativeBuildInputs = [config.deps.python.pkgs.flit-core];
  };
}
