{
  dlib,
  lib,
}: let
  b = builtins;
in {
  # the input format is specified in /specifications/translator-call-example.json
  # this script receives a json file including the input paths and extraArgs
  translateBin = {
    # dream2nix
    externalSources,
    utils,
    bash,
    coreutils,
    jq,
    nix,
    python3,
    writeScriptBin,
    ...
  }: let
    machNixExtractor = "${externalSources.mach-nix}/lib/default.nix";

    setuptools_shim = ''
      import sys, setuptools, tokenize, os; sys.argv[0] = 'setup.py'; __file__='setup.py';
      f=getattr(tokenize, 'open', open)(__file__);
      code=f.read().replace('\r\n', '\n');
      f.close();
      exec(compile(code, __file__, 'exec'))
    '';
  in
    utils.writePureShellScript
    [
      bash
      coreutils
      jq
      nix
    ]
    ''
      # accroding to the spec, the translator reads the input from a json file
      jsonInput=$1

      # read the json input
      outputFile=$(${jq}/bin/jq '.outputFile' -c -r $jsonInput)
      source=$(${jq}/bin/jq '.source' -c -r $jsonInput)
      pythonAttr=$(${jq}/bin/jq '.pythonAttr' -c -r $jsonInput)
      application=$(${jq}/bin/jq '.application' -c -r $jsonInput)

      # build python and pip executables
      tmpBuild=$(mktemp -d)
      nix build --show-trace --impure --expr \
        "
          (import ${machNixExtractor} {}).mkPy
            (import <nixpkgs> {}).$pythonAttr
        " \
        -o $tmpBuild/python
      nix build --impure --expr "(import <nixpkgs> {}).$pythonAttr.pkgs.pip" -o $tmpBuild/pip
      python=$tmpBuild/python/bin/python
      pip=$tmpBuild/pip/bin/pip

      # prepare temporary directory
      tmp=$(mktemp -d)

      # extract python requirements from setup.py
      cp -r $source $tmpBuild/src
      chmod -R +w $tmpBuild/src
      cd $tmpBuild/src
      chmod +x setup.py || true
      echo "extracting dependencies"
      out_file=$tmpBuild/python.json \
          dump_setup_attrs=y \
          PYTHONIOENCODING=utf8 \
          LANG=C.utf8 \
        $python -c "${setuptools_shim}" install &> $tmpBuild/python.log || true

      # extract requirements from json result
      $python -c "
      import json
      result = json.load(open('$tmpBuild/python.json'))
      for key in ('install_requires', 'setup_requires'):
        if key in result:
          print('\n'.join(result[key]))
      " > $tmpBuild/computed_requirements

      # download files according to requirements
      $tmpBuild/pip/bin/pip download \
        --no-cache \
        --dest $tmp \
        --progress-bar off \
        -r $tmpBuild/computed_requirements
        # -r ''${inputFiles/$'\n'/$' -r '}

      # generate the dream lock from the downloaded list of files
      NAME=$(${jq}/bin/jq '.name' -c -r $tmpBuild/python.json) \
          VERSION=$(${jq}/bin/jq '.version' -c -r $tmpBuild/python.json) \
        $tmpBuild/python/bin/python ${./generate-dream-lock.py} $tmp $jsonInput

      rm -rf $tmp $tmpBuild
    '';

  compatible = {source}:
    dlib.containsMatchingFile
    [
      ''.*requirements.*\.txt''
    ]
    source;

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

    application = {
      description = "build application instead of package";
      type = "flag";
    };
  };
}
