# Build your nodejs project with nix in 10 minutes or less

{{#include ../warning.md}}

This guide takes you step-by-step through setting up a nodejs
reproducible build and development environment using nix (the build
system) and dream2nix (bridge between external package managers and nix).

This setup will allow for the same environment to be reproduced on
different machines and CI systems with high accuracy - thus avoiding
many pitfalls of distributed software development.

## Outline
0. Install nix with flakes enabled
1. Navigate to your nodejs project
2. Initialize the dream2nix flake
3. Define target platform(s)
4. Explore the outputs
5. Build the project
6. Development shell
7. FAQ

{{#include ../install-nix.md}}

## Navigate to your nodejs project
For this guide we will use the fun
[`cowsay`](https://github.com/piuccio/cowsay) nodejs project.
It is simply a talking cow for your console. This project is a nodejs
port from the original perl version.
Feel free to use any other project, if you do and hit a roadblock,
please consult the [FAQ](#FAQ) at the end of this article for solutions
to some common issues.

We start by cloning the project:
```command
> git clone https://github.com/piuccio/cowsay /tmp/my_project
> cd /tmp/my_project
```

## Initialize the dream2nix flake
We have our repository cloned and ready. Now we will create the flake.

The flake is a standalone description of the project, it will define the
inputs and outputs of our project, the build steps - in this case
handled by dream2nix, and the development environment.
The flake is a fully standalone and complete configuration for nix to
build a software package.

We use a dream2nix flake template:
```command
> nix flake init -t github:nix-community/dream2nix#simple
wrote: /tmp/my_project/flake.nix
```
to create a `flake.nix`:
```nix
{
  inputs.dream2nix.url = "github:nix-community/dream2nix";
  outputs = inp:
    inp.dream2nix.lib.makeFlakeOutputs {
      systemsFromFile = ./nix_systems;
      config.projectRoot = ./.;
      source = ./.;
      projects = ./projects.toml;
    };
}
```
This file configures our build and development environment using the
dream2nix framework to bridge the nodejs ecosystem into nix. This let's
nix read and understand `package.json` and how to install and link
nodejs packages - to avoid duplication of dependency definitions and
build steps.

{{#include ../define-targets.md}}

## Explore the outputs
We have setup the flake, defined our target system(s), now we are ready
to use it. Let's start by listing out what is available to us (actual
output may be different, this is a shortened version):
```command
> nix flake show
warning: Git tree '/tmp/my_project' is dirty
warning: creating lock file '/tmp/my_project/flake.lock'
warning: Git tree '/tmp/my_project' is dirty
git+file:///tmp/my_project
├───devShell
│   └───x86_64-linux: development environment 'nix-shell'
├───devShells
│   └───x86_64-linux
│       ├───cowsay: development environment 'nix-shell'
│       └───default: development environment 'nix-shell'
└───packages
    └───x86_64-linux
        ├───cowsay: package 'cowsay-1.5.0'
        ├───default: package 'cowsay-1.5.0'
        └───resolveImpure: package 'resolve'
```

We can see that:
1. `warning: Git tree '/tmp/my_project' is dirty`
Our repository has uncommitted changes.
Nix uses git commit hashes to version build artifacts,
so this can result in some extra rebuilds.
Since we are just setting up the project now, this is alright.
1. `warning: creating lock file '/tmp/my_project/flake.lock'`
Our flake itself has an input (external dependency), the `dream2nix`
framework. When we first use the flake, like we just did, nix created a
lock file with the exact version of the input (and its inputs). Commit
this file to version control to ensure reproducible builds.
1. Finally, we see the outputs of our flake.
We see it outputs `packages` for the `x86_64-linux` systems:
the `cowsay` package (our nodejs project) and a `resolveImpure` package
(more about that in the next section). It also sets out `cowsay` package
as the `default` package of this flake.

## Build the project
We have setup our flake for the nodejs project and identified the
output we want to build.

To build the output, we run:
```command
> nix build .#cowsay
```
(The `.` means the flake in the current directory, `#` is a special
character separating the flake name and the package name, and `cowsay` is
the name of the package we want to build. Since we want to `build`, nix
will look under `packages` first, and it knows our current platform
(`x86_64-linux` in this case), so it will actually build the output
`.#packages.x86_64-linux.cowsay`.)

Since, `cowsay` is the `default` package, we could also simply run:
```command
> nix build
```
To build the `.#packages.x86_64-linux.default` output. (In our case
these are the same.)

This creates our `./result` directory with all our final build
artifacts.
```command
> ./result/bin/cowsay 'hello dream2nix'
 _________________
< hello dream2nix >
 -----------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

Nix was able to build this project, because it has a `package-lock.json`
file pinning the exact dependency versions. If we did not have this
file, the `nix build` would fail with `error: unresolved impurities`.
```command
> git rm package-lock.json
> nix build .#cowsay
warning: Git tree '/tmp/my_project' is dirty
error: The nodejs package cowsay contains unresolved impurities.
       Resolve by running the .resolve attribute of this derivation
       or by resolving all impure projects by running the `resolveImpure` package
```
We can fix this by generating a language specific lockfile
(`package-lock.json` or `yarn.lock` for nodejs), or let dream2nix
generate a universal `dream-lock.json`.
```command
> nix run .#resolveImpure
warning: Git tree '/tmp/my_project' is dirty
Resolving:: Name: cowsay; Subsystem: nodejs; relPath:
translating in temp dir: /tmp/tmp.SwBFt0WcH4

up to date, audited 172 packages in 9s

57 packages are looking for funding
  run `npm fund` for details

3 high severity vulnerabilities

To address all issues (including breaking changes), run:
  npm audit fix --force

Run `npm audit` for details.
===[SUCCESS]===(dream2nix-packages/cowsay/dream-lock.json)===
adding file to git: dream2nix-packages/cowsay/dream-lock.json
```
This runs `npm` behind the scenes and resolves dependencies for all
packages inside the flake.

There is no difference between using an external lockfile or
`dream-lock.json`, all they do is pin dependency version and are
completely interchangeable.

## Development shell
We were able to build our nodejs project with nix, however our build
artifacts under `./result` are read-only and we do not have `node` and
`npm` in `PATH`. To be able to work in this project we will need those.

Nix provides us with `devShells` for exactly this.
```command
> nix flake show
warning: Git tree '/tmp/my_project' is dirty
warning: creating lock file '/tmp/my_project/flake.lock'
warning: Git tree '/tmp/my_project' is dirty
git+file:///tmp/my_project
├───devShell
│   └───x86_64-linux: development environment 'nix-shell'
├───devShells
│   └───x86_64-linux
│       ├───cowsay: development environment 'nix-shell'
│       └───default: development environment 'nix-shell'
└───packages
    └───x86_64-linux
        ├───cowsay: package 'cowsay-1.5.0'
        ├───default: package 'cowsay-1.5.0'
        └───resolveImpure: package 'resolve'
```
When we enter the `cowsay` development shell, we will get `node` in our
`PATH`, together with all the binaries from our dependencies packages.
And nix will copy over `node_modules` for us to save us from having to
`npm install` everything over again.
To get in the shell, simply run:
```command
> nix develop -c $SHELL
```
(The `-c $SHELL` part is only necessary if you use a different shell than bash
and would like to bring that shell with you into the dev environment.)

From here on it's the same as using a normal installation of nodejs.
However, if we do imperative changes to `node_modules` and later
re-enter the nix development shell, nix will overwrite the
`node_modules` with the pinned versions of the dependencies from our
lockfile.

## FAQ

### Refusing to overwrite existing file on `flake init`.

When initializing a flake it needs to write some files, if these already
exists, the initialization will fail. Since our repository is under
version control, we can delete the conflicting files, let `flake init`
create them and then check the diff and merge the changes manually.

### Getting status of `flake.nix`: no such file or directory.

The flake build does not happen inside the directory. Nix copies your
repository to a temporary location and builds there; only files under
version control are used. To resolve this run `git add flake.nix` and
all other missing files.

### Warning: Git tree is dirty

This is just a warning, nix is using the git revision for build artifact
versioning. Having a dirty git tree - meaning uncommitted changes - can
lead to some extra rebuilds, for simple projects this should not be a
major concern.

### error: The package contains unresolved impurities. Resolve all impure projects by running the `resolveImpure` package.

This happens when dream2nix cannot resolve exact package versions. We
can define a dependency like `something@^2.1`, but it is not obvious if
we actually want `2.1.1` or `2.1.2` or maybe `2.1.1-alpha`.
There are 2 ways to resolve this error: either by running
`nix run .#resolveImpure` and letting dream2nix resolve the most
up-to-date versions of all dependencies, or using an external package
manager to generate a lock file, which can be later read by dream2nix.
(In case of Node.js, both `package-lock.json` and `yarn.lock` are
supported.)
