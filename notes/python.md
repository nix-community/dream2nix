# Plans to extend the python subsystem

This file contains notes on planned features and possible challenges of the python subsystem for dream to nix.
Documentation for the existing features can be found in [docs/src/subsystems/python.md](../docs/src/subsystems/python.md).

## Current Limitations

- Only an impure translator (python-pip) included
- Existing (simple-python) builder outputs everything into a single derivation.

## Goal

We'd like to eventually support as many python projects as possible through pure translators and output them into separate derivations per dependency.

While that won't be possible for projects desclaring their dependencies in simple `requirements.txt` without hashes, it should be for those using hashes in `requirements.txt` or `poetry.lock`, `pipenv.lock` and similar files. The same is true for `name`, `version` and build-time dependencies of the package to be built itself: Due to the possiblity to execute arbitrary code in `setup.py` it won't be possible to cover all cases, but parsing `setup.cfg`, `pyproject.toml` and using heuristics for `setup.py` it should be possible to cover the vast majority of cases.


## Desired Outcome

1. A python environment with all packages from one or more requirements.txt files with exact versions and optionally hashes.

2. The same environment with one or more python packages installed from (subdirectories of) a repo.

3. Like 2 but packages installed in editable mode.
