## Motivation

A project consists of multiple python packages in different subdirectories. Each
of these has dependencies and optional dev dependencies. Compiled requirements
with hashes exist, written with pip-compile:

- ``code1/pypkg1/requirements.txt``
- ``code1/pypkg1/requirements-dev.txt``

Two modes of operation:

1. Use compiled requirements files and create nix lock files accordingly.
2. Create nix lock files without using compiled requirements, but only
   dependency declarations in pyproject.toml, and pip-compile afterwards for
   projects not using nix.

We'd like to create environments where requirements for individual packages and
combinations of these packages are available.

For the projects' python packages:

1. Do not install, environment with requirements only.

2. Install selected packages.

3. Install selected packages in editable mode.
