<p align="center">
<img width="400" src="https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/e2a12a60ae49aa5eb11b42775abdd1652dbe63c0/dream2nix-01.png">
</p>

## dream2nix - A framework for automated nix packaging

!!! Warning: dream2nix is unstable software. While simple UX is one of our main focus points, the APIs  are still under development. Do expect changes that will break your setup.

Jump to:
- [Quick Start](https://nix-community.github.io/dream2nix/guides/quick-start.html)
- [Documentation](https://nix-community.github.io/dream2nix)

dream2nix is a framework for automatically converting packages from other build systems to nix.

It focuses on the following aspects:

- Modularity
- Customizability
- Maintainability
- Nixpkgs Compatibility, by not enforcing IFD (import from derivation)
- Code de-duplication across 2nix converters
- Code de-duplication in nixpkgs
- Risk-free opt-in aggregated fetching (larger [FODs](https://nixos.wiki/wiki/Glossary), less checksums)
- Common UI across 2nix converters
- Reduce effort to develop new 2nix solutions
- Exploration and adoption of new nix features
- Simplified updating of packages

The goal of this project is to create a standardized, generic, modular framework for automated packaging solutions, aiming for better flexibility, maintainability and usability.

The intention is to integrate many existing 2nix converters into this framework, thereby improving many of the previously named aspects and providing a unified UX for all 2nix solutions.

### Documentation

Documentation can be found at [nix-community.github.io/dream2nix](https://nix-community.github.io/dream2nix).

The documentation is also available in your terminal inside the dream2nix dev shell via `d2n-docs [keyword]` or by running:  
`nix run github:nix-community/dream2nix#docs [keyword]`
### Funding

This project receives financial support by [NLNet](https://nlnet.nl/) as part of the [NGI Assure Programme](https://nlnet.nl/assure/) funded by the European Commission.

If your organization wants to support the project with extra funding in order to add support for more languages or new features, please contact one of the maintainers.

### Community

matrix: https://matrix.to/#/#dream2nix:nixos.org

### Watch the presentation

(The code examples of the presentation are outdated)
[![dream2nix - A generic framework for 2nix tools](https://gist.githubusercontent.com/DavHau/755fed3774e89c0b9b8953a0a25309fa/raw/3c8b2c56f5fca3bf5c343ffc179136eef39d4d6a/dream2nix-youtube-talk.png)](https://www.youtube.com/watch?v=jqCfHMvCsfQ)
