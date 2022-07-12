# Indexers

Indexers are programs that can query a package repository (think of npm, or crates.io) for package information.
This information mainly consists of the package name, the package version, and anything extra that might be useful / needed to fetch / translate it.
The information is stored as a "source shortcut", which basically follows the format `proto1+proto2:pname/version?key=value&key2=value2`.

Examples:
- `npm:execa/6.1.0`
- `crates-io:ripgrep/13.0.0?hash=somehash`
- `git+ssh://github.com/owner/repo?rev=refs/heads/v1.2.3&dir=sub/dir`.
- etc.

## Indexer inputs

Indexers take input as a path to a JSON file, which contains information needed by that specific indexer.
A common attribute for these inputs across indexers are `outputFile`, which should be the path to output the generated index to.
Indexers can vary in functionality, so these JSON inputs should be specified under `src/specifications/indexers/`.

## Indexer outputs

Indexers should output their generated index to where `outputFile` specifies.
This index should simply be a list of source shortcuts in JSON. Example:

```json
[
  "npm:execa/6.1.0",
  "npm:meow/10.1.3",
  "npm:npm-run/5.0.1"
]
```

## Current indexers

Following are the current indexers implemented in dream2nix:

- crates.io indexer (named `crates-io`)
- NPM indexer (named `npm`)
