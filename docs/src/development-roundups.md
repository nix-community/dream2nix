# Regular development roundups for dream2nix

## Development Roundup April - June 2022

In the period of 3 months, [40 pull requests were merged](https://github.com/nix-community/dream2nix/pulls?page=1&q=is%3Apr+sort%3Acreated-asc+merged%3A2022-06+merged%3A2022-05+merged%3A2022-04).

### Most Notable Changes
#### Extension Interface for subsystem modules
Dream2nix now has an extension interface which allows users to add support for other ecosystems and lock file formats out of tree. This allows people to maintain private dream2nix extensions or publish their extensions on their own repositories. For the future it is planned to go one step further and use the nixos module system for dream2nix.

#### Improved handling of mono-repo projects
Many software projects in the wild consist of several sub-project. The sub-projects could be of the same ecosystem, like a nodejs project managed by npm, declaring several workspaces, or they could be of completely different ecosystems, like a nodejs project, containing a rust and a go module within the same source tree. A goal for dream2nix is to handle all these constellations well, to provide the user with decent automation and interfaces in order to simplify working with these complex software projects as much as possible. Therefore a discovery mechanism has been established and improved over time to tackle mono-repo scenarios, detecting sub-projects of arbitrary type within a larger source tree, splitting the detected projects into reasonable chunks of work that can be processed by many different translator modules of dream2nix.

#### Unit tests for pure translators
Pure translators are the parts of dream2nix which are able to read upstream lock files and other metadata and convert this data to the dream2nix internal dream-lock format. All of this in done in pure nix without calling to external programs. For example the cargo-lock translator allows dream2nix to just build any rust project on-the-fly, given just the source code of the project.
In order for dream2nix to extend its support onto many more ecosystems, we rely on the community contributions adding pure translators. For this reason we want to make such contributions as simple as possible.
This is why we established a unit testing suit for pure translators. This is realized by using python + pytest to define the unit tests which then call out to nix via our python nix-ffi. This allows people to implement new translators step by step while getting constant feedback if they are on the right track.

### More Changes
- New community overrides to fix some nodejs packages
- Improved usage examples in readme
- Improvements on several subsystems including nodejs and rust
- New documentation website:
https://nix-community.github.io/dream2nix/

- Added subsystems:
  - python
  - haskell
- Added support for formats:
  - python: setup.py
  - haskell: stack.yaml.lock (stack)
  - haskell: plan.json (cabal)
  - rust: Cargo.toml
