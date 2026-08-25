# fetchComposerMetadata reads composer.json and composer.lock,
# and prefetches git hashes to generate a dream2nix lock file.
{
  lib,
  writeText,
  python3,
  # Arguments for the script
  composerJsonPath ? "composer.json",
  composerLockPath ? "composer.lock",
  projectName ? null,
  noDev ? false,
  nativeBuildInputs ? [],
  # executable that returns the project root
  findRoot,
  nix,
  nix-prefetch-scripts,
  gitMinimal,
  openssh,
  coreutils,
  writePureShellScript,
}: let
  package = import ./package.nix {
    inherit lib python3 nix-prefetch-scripts;
  };

  # nix-prefetch-git needs nix-hash from the nix package
  path = [coreutils gitMinimal openssh nix nix-prefetch-scripts] ++ nativeBuildInputs;

  args = writeText "composer-args" (builtins.toJSON {
    inherit
      composerJsonPath
      noDev
      composerLockPath
      projectName
      ;
  });

  script =
    writePureShellScript
    path
    ''
      ${package}/bin/fetch_composer_metadata \
        --json-args-file "${args}"
    '';
in
  script
