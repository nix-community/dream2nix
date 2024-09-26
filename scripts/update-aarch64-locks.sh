#! /usr/bin/env bash

ssh hetzner@mac01.numtide.com "
  cd dave/dream2nix/examples/packages/languages/python-local-development \
  && git pull \
  && nix run .#default.lock
"

scp hetzner@mac01.numtide.com:~/dave/dream2nix/examples/packages/languages/python-local-development/lock.aarch64-darwin.json \
  examples/packages/languages/python-local-development/lock.aarch64-darwin.json
