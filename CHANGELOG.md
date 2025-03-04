# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

## [Unreleased]

### Added

#### Unified override interface across languages

New options `overrides.${name}` and `overrideAll` for all language modules that manage a dependency tree.

### Changed

#### Modified choice of output used as top-level output in package-func

Changed the top-level output selected for multi-output derivations to be  the first output declared in `package-func.outputs` or the default output (if the attribute `outputSpecified` is true) instead of 'out'.