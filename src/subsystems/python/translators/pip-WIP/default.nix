{
  dlib,
  lib,
  ...
}: let
  b = builtins;
in {
  type = "impure";

  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and extraArgs
  translateBin = {
    externalSources,
    utils,
    bash,
    coreutils,
    jq,
    nix,
    python3,
    remarshal,
    toml2json,
    writeScriptBin,
    ...
  }:
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
      remarshal
      toml2json
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$WORKDIR/$(jq '.outputFile' -c -r $jsonInput)
      source="$(jq '.source' -c -r $jsonInput)/$(jq '.project.relPath' -c -r $jsonInput)"
      name="$(jq '.project.name' -c -r $jsonInput)"
      pythonAttr=$(jq '.project.subsystemInfo.pythonAttr' -c -r $jsonInput)
      extraRequirements=$(jq '.project.subsystemInfo.extraRequirements' -c -r $jsonInput)

      # build python and pip executables
      tmpBuild=$(mktemp -d)
      nix build \
        --impure \
        --expr "(import <nixpkgs> {}).$pythonAttr.withPackages (ps: with ps; [pip setuptools $extraRequirements])" \
        -o $tmpBuild/python
      python=$tmpBuild/python/bin/python

      # prepare temporary directory
      tmp=$(mktemp -d)

      # prepare source
      cp -r $source ./source
      chmod +w -R ./source

      # download setup dependencies from pyproject.toml
      toml2json ./source/pyproject.toml | jq '."build-system".requires[]' -r > __setup_reqs.txt || :
      $python -m pip download \
        --dest $tmp \
        --progress-bar off \
        -r __setup_reqs.txt

      # download files according to requirements
      $python -m pip download \
        --dest $tmp \
        --progress-bar off \
        -r __setup_reqs.txt \
        ./source

      # generate the dream lock from the downloaded list of files
      cd ./source
      export NAME=$name
      export VERSION=$($python ./setup.py --version 2>/dev/null)
      cd $WORKDIR
      $python ${./generate-dream-lock.py} $tmp $jsonInput

      rm -rf $tmp $tmpBuild
    '';

  # define special args and provide defaults
  extraArgs = {
    # the python attribute
    pythonAttr = {
      default = "python3";
      description = "python version to translate for";
      examples = [
        "python27"
        "python39"
        "python310"
      ];
      type = "argument";
    };

    extraRequirements = {
      default = "";
      description = "a list of extra requirements to add";
      examples = [
        "cython"
        "numpy"
      ];
      type = "argument";
    };

    application = {
      description = "build application instead of package";
      type = "flag";
    };
  };
}
