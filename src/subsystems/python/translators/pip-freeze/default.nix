/*
This is an example for a pure translator which translates niv's sources.json
  to a dream2nix dream-lock(.json).

Example sources.json: https://github.com/nmattia/niv/blob/351d8bc316bf901a81885bab5f52687ec8ccab6e/nix/sources.json
*/
{
  dlib,
  lib,
  inputs,
  ...
}: let
  l = lib // builtins;

  # get sdist and wheel files from a python package candidate
  getFiles = name: ver: let
    dbSrc = inputs.nix-pypi-fetcher;
    pname = l.replaceStrings ["_"] ["-"] (l.toLower name);
    pnameAlt = l.replaceStrings ["-"] ["."] pname;
    bucketHash = l.hashString "sha256" pname;
    bucketHashAlt = l.hashString "sha256" pnameAlt;
    bucket = l.substring 0 2 bucketHash;
    bucketAlt = l.substring 0 2 bucketHashAlt;
    json = l.fromJSON (l.readFile (dbSrc + /pypi + "/${bucket}.json"));
    jsonAlt = l.fromJSON (l.readFile (dbSrc + /pypi + "/${bucketAlt}.json"));
    files =
      json.${pname}.${ver}
      or jsonAlt.${pnameAlt}.${ver};
  in
    files;

  parseWheelFname = fn: let
    fnNoSuffix = l.removeSuffix ".whl" fn;
    split = l.splitString "-" fnNoSuffix;
    last = (l.length split) - 1;
  in {
    abi = l.elemAt split (last - 1);
    file = fn;
    platform = l.elemAt split last;
    pyabi = l.elemAt split (last - 2);
  };
in {
  type = "pure";
  discoverProject = tree:
    l.pathExists "${tree.fullPath}/requirements.txt";

  # translate from a given source and a project specification to a dream-lock.
  translate = {
    project,
    tree,
    pythonVersion,
    system,
    requirementsFiles ? ["requirements.txt"],
    ...
  }:
  # if system == null
  # then throw "please specify: "
  let
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

    nameVersion = builtins.match ''^([[:alnum:]\.\_\-]+)[^=]*==([^[:space:];\]+).*'';
    # [{ name = "foo"; version = "1.2.3"; }, ...]
    readRequirements = path: let
      lines = l.splitString "\n" (l.readFile path);
      matched = l.filter (m: m != null) (l.map (line: nameVersion line) lines);
      reqs =
        l.map (match: {
          name = l.elemAt match 0;
          version = l.elemAt match 1;
        })
        matched;
    in
      reqs;

    reqList = l.concatLists (l.map (file: readRequirements "${projectSource}/${file}") requirementsFiles);

    defaultPackageName = "default"; # pyproject.toml
    defaultPackageVersion = "unknown-version";

    getSource = {
      name,
      version,
    }: let
      files = getFiles name version;
      wheelFnames = l.attrNames (files.wheels or {});
      wheels = map parseWheelFname wheelFnames;
      wheel = pep425.selectWheel wheels;
      wheelFn = (l.head wheel).file;
      wheelFile = files.wheels.${wheelFn};
      wheelPyVer = l.elemAt wheelFile 1;
      wheelHash = l.elemAt wheelFile 0;
      nameFirstChar = l.substring 0 1 name;
      sdistFn = l.elemAt files.sdist 1;
      sdistHash = l.elemAt files.sdist 0;
      wheelUrl = "https://files.pythonhosted.org/packages/${wheelPyVer}/${nameFirstChar}/${name}/${wheelFn}";
      sdistUrl = "https://files.pythonhosted.org/packages/source/${nameFirstChar}/${name}/${sdistFn}";
      url =
        if wheel != []
        then wheelUrl
        else sdistUrl;
      hash =
        if wheel != []
        then "sha256-${wheelHash}"
        else "sha256-${sdistHash}";
    in {
      type = "http";
      inherit hash url;
    };
    sources =
      l.foldl
      # Multiple versions are not supported, but preserved here through deep update.
      (all: req: all // {${req.name} = all.${req.name} or {} // {${req.version} = getSource req;};})
      {}
      reqList;
  in
    # see example in src/specifications/dream-lock-example.json
    {
      decompressed = true;

      # generic fields
      _generic = {
        defaultPackage = defaultPackageName;

        location = project.relPath;

        packages = {
          "${defaultPackageName}" = defaultPackageVersion;
        };

        subsystem = "python";
      };

      _subsystem = {
        inherit reqList;
        application = false;
        pythonAttr = "python3";
        sourceFormats = {};
      };

      cyclicDependencies = {};
      dependencies = {};

      inherit sources;
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
