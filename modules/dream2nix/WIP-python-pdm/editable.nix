{
  runCommand,
  lib,
  pyproject,
  python,
  editablePackageSources,
  libpyproject,
}: let
  name = libpyproject.pypa.normalizePackageName pyproject.project.name;

  # Just enough standard PKG-INFO fields for an editable installation
  pkgInfoFields = {
    Metadata-Version = "2.1";
    Name = name;
    Version = pyproject.project.version;
    Summary = pyproject.project.description;
  };

  pkgInfoFile =
    builtins.toFile "${name}-PKG-INFO"
    (lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key}: ${value}") pkgInfoFields));

  # A python package that contains simple .egg-info and .pth files for an editable installation
  editablePackage = python.pkgs.toPythonModule (
    runCommand "${name}-editable"
    {} ''
      mkdir -p "$out/${python.sitePackages}"
      cd "$out/${python.sitePackages}"

      # See https://docs.python.org/3.8/library/site.html for info on such .pth files
      # These add another site package path for each line
      touch pdm-editable.pth
      ${lib.concatMapStringsSep "\n"
        (src: ''
          echo "${toString src}" >> pdm-editable.pth
        '')
        (lib.attrValues editablePackageSources)}

      # Create a very simple egg so pkg_resources can find this package
      # See https://setuptools.readthedocs.io/en/latest/formats.html for more info on the egg format
      mkdir "${name}.egg-info"
      cd "${name}.egg-info"
      ln -s ${pkgInfoFile} PKG-INFO
    ''
  );
in
  editablePackage
