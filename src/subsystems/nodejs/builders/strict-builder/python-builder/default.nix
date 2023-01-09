# our builder, written in python. Better handles the complexity with how npm
# builds node_modules
{pkgs, ...}: {
  nodejsBuilder = pkgs.python310Packages.buildPythonApplication {
    name = "builder";
    src = ./.;
    format = "pyproject";
    nativeBuildInputs = with pkgs.python310Packages; [poetry mypy flake8 black];
    doCheck = false;
  };
}
