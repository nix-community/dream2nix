/*
This is a pure translator which translates poetry's poetry.lock
  to a dream2nix dream-lock(.json).

Example poetry.lock: https://github.com/python-poetry/poetry/blob/master/poetry.lock
*/
{
  dlib,
  lib,
  inputs,
  ...
}: let
  l = lib // builtins;
in {
  type = "pure";

  discoverProject = tree:
    l.pathExists "${tree.fullPath}/poetry.lock";

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    project,
    tree,
    pythonVersion,
    system,
    ...
  }: let
    # get the root source and project source
    rootSource = tree.fullPath;
    projectSource = "${tree.fullPath}/${project.relPath}";
    projectTree = tree.getNodeFromPath project.relPath;

    # initialize poetry2nix libs
    fakeStdenv = {
      isLinux = l.hasInfix "-linux" system;
      isDarwin = l.hasInfix "-darwin" system;
      targetPlatform.isAarch64 = l.hasPrefix "aarch64-" system;
      targetPlatform.parsed.cpu.name = l.elemAt (l.splitString "-" system) 0;
    };
    fakePython = {
      version = pythonVersion;
      passthru.implementation = "cpython";
    };
    pep425 = import "${inputs.poetry2nix}/pep425.nix" {
      inherit lib;
      python = fakePython;
      stdenv = fakeStdenv;
      poetryLib = import "${inputs.poetry2nix}/lib.nix" {
        inherit lib;
        pkgs = null;
        stdenv = fakeStdenv;
      };
    };

    # use dream2nix' source tree abstraction to access json content of files
    poetryLock =
      (projectTree.getNodeFromPath "poetry.lock").tomlContent;

    pyproject = (projectTree.getNodeFromPath "pyproject.toml").tomlContent;
    defaultPackageName = pyproject.tool.poetry.name;
    defaultPackageVersion = pyproject.tool.poetry.version;

    computeSource = sourceName: files: let
      wheels = pep425.selectWheel files;
      sdists = builtins.filter (x: !(lib.hasSuffix ".whl" x.file)) files;
      candidate =
        if lib.length wheels > 0
        then builtins.head wheels
        else builtins.head sdists;
      isWheel = l.hasSuffix "whl" candidate.file;
      suffix =
        if isWheel
        then ".whl"
        else ".tar.gz";
      parts = lib.splitString "-" (lib.removeSuffix suffix candidate.file);
      last = (lib.length parts) - 1;
      pname =
        if isWheel
        then lib.elemAt parts (last - 4)
        else builtins.concatStringsSep "-" (lib.init parts);
      version =
        if isWheel
        then lib.elemAt parts (last - 3)
        else lib.elemAt parts last;
    in {
      ${version} =
        if isWheel
        then {
          type = "pypi-wheel";
          filename = candidate.file;
          hash = candidate.hash;
        }
        else {
          type = "pypi-sdist";
          inherit pname version;
          hash = candidate.hash;
        };
    };
  in
    # see example in src/specifications/dream-lock-example.json
    {
      decompressed = true;
      # generic fields
      _generic = {
        # TODO: specify the default package name
        defaultPackage = defaultPackageName;
        # TODO: specify a list of exported packages and their versions
        packages.${defaultPackageName} = defaultPackageVersion;
        # TODO: this must be equivalent to the subsystem name
        subsystem = "python";
        location = project.relPath;
      };

      _subsystem = {
        application = false;
        pythonAttr = "python3";
        sourceFormats = {};
      };

      cyclicDependencies = {};

      dependencies = {};

      sources =
        if poetryLock ? metadata.files
        # the old poetry lock format
        then l.mapAttrs computeSource poetryLock.metadata.files
        # the newer format
        else
          l.listToAttrs (
            l.map
            (package:
              l.nameValuePair
              package.name
              (computeSource package.name package.files))
            poetryLock.package
          );
    };

  extraArgs = {
    system = {
      description = "System for produced outputs.";
      # default = "blabla";
      examples = [
        "x86_64-linux"
        "x86_64-darwin"
      ];
      type = "argument";
    };
    pythonVersion = {
      description = "python version to translate for";
      default = "3.10";
      examples = [
        "3.8"
        "3.9"
        "3.10"
      ];
      type = "argument";
    };
  };
}
