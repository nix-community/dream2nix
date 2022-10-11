# Generic lockfile

The generic lockfile is interpreted from the fetchers and dependencies are loaded based on their type.

When dream2nix reads project dependencies and translates them into
a dream2nix lockfile, it writes down the sources for all the
dependencies: so it can fetch them later during building.

The generic lockfile is used always, either in memory or dumped to a file. 


Below are some examples of the sources written in the dream-lock file
(at the end, under `sources`).

```json
"symfony/process": {
  "v6.1.3": {
    "rev": "a6506e99cfad7059b1ab5cab395854a0a0c21292",
    "type": "git",
    "url": "https://github.com/symfony/process.git"
  }
}
```

```json
"fast-glob": {
  "3.2.11": {
    "hash": "sha512-xrO3+1bxSo3ZVHAnqzyuewYT6aMFHRAd4Kcs92MAonjwQZLsK9d0SF1IyQ3k5PoirxTW0Oe/RqFgMQ6TcNE5Ew==",
    "type": "http",
    "url": "https://registry.npmjs.org/fast-glob/-/fast-glob-3.2.11.tgz"
  }
}
```

The `type` field tells dream2nix what [fetchers](../intro/fetchers.md) to invoke to get this
source, the rest of the attributes are simply passed to the fetcher.