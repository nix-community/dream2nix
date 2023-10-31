#!/usr/bin/env bash

# find script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# find examples directory
packagesDir="$DIR/../examples/packages"

# iterate over all double nested package directories and copy the flake file there
echo "$packagesDir"/*/*/ | xargs -n 1 cp "$DIR"/flake.nix
