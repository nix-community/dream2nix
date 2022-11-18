{
  pkgs,
  lib,
  package,
  src,
}:
pkgs.runCommand "package-test" {
  nativeBuildInputs = [package];
  src = src;
} ''
  echo Tests runnning....
  ls -la ./
  echo binaries of $packageName failed
  exit 1
''
