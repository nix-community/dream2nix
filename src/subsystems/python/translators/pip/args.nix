{
  pythonAttr = {
    description = "python version to translate for";
    default = "python3";
    examples = [
      "python27"
      "python39"
      "python310"
    ];
    type = "argument";
  };

  extraSetupDeps = {
    description = ''
      a list of extra setup reqirements to install before executing 'pip download'
    '';
    default = [];
    examples = [
      "cython"
      "numpy"
    ];
    type = "argument";
  };
}
