#!/usr/bin/env bash
set -eou pipefail

export NUM_PKGS=${1:-100}
export NUM_VARS=${2:-100}

# measure date ini milliseconds
echo -e "\nBenchmarking ${NUM_PKGS}x builtins.derivaton via pkg-funcs"
time nix eval --impure -f ./builtins-derivation-modules-vs-pkg-func.nix --json pkg-funcs > /dev/null

echo -e "\nBenchmarking ${NUM_PKGS}x builtins.derivaton via modules"
time nix eval --impure -f ./builtins-derivation-modules-vs-pkg-func.nix --json modules > /dev/null

echo -e "\nBenchmarking ${NUM_PKGS}x mkDerivation via pkg-funcs"
time nix eval --impure -f ./mkDerivation-modules-vs-pkg-func.nix --json pkg-funcs > /dev/null

echo -e "\nBenchmarking ${NUM_PKGS}x mkDerivation via modules"
time nix eval --impure -f ./mkDerivation-modules-vs-pkg-func.nix --json modules > /dev/null
