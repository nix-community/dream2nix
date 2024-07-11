---
title: "pip"
state: released
maintainers:
  - phaer
---

A module to package python projects via [pip](https://pip.pypa.io/).

Under the hood, it uses [./pkgs/fetchPipMetadata](https://github.com/nix-community/dream2nix/tree/main/pkgs/fetchPipMetadata) to
run `pip install --dry-run --report [...]` with reproducible inputs and converts the resulting installation report into a dream2nix
lock file.

!!! note

    Due to limitations in `pip`s cross-platform support, the resulting
    lock-files are platform-specific!
    We therefore recommend setting `paths.lockFile` to `lock.${system}.json`
    for all projects where you use the pip module.

    Check out the [pdm module](../WIP-python-pdm/index.md) if you need a solution that
    allows locking for multiple platforms at once!

During building, it uses this lock file to build each dependency as well as the top-level package in separate derivations
while allowing overrides and further customization via [dream2nix module system](../../modules.md).
