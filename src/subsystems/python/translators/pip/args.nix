{
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
