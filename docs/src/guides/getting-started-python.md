# Build your python project with nix in 10 minutes

{{#include ../warning.md}}

This guide walks you through the process of setting up nix for your project using dream2nix. This will allow your project's build and dev-environment to be reproduced by machines of other developers or CI systems with high accuracy.

## Outline

0. Install nix
1. Navigate to your python project
2. Initialize the dream2nix flake
3. Define target platform(s)
4. List the available packages
5. Build the project
6. Create a development shell
7. Resolve impurities

{{#include ../install-nix.md}}

## Navigate to your python project
In this example I will clone the python project [`httpie`](https://github.com/httpie/httpie) to `/tmp/my_project` as an example.
```command
> git clone https://github.com/httpie/httpie /tmp/my_project
> cd /tmp/my_project
```

## Initialize the dream2nix flake.nix
```command
> nix flake init -t github:nix-community/dream2nix#simple
wrote: /tmp/my_project/flake.nix
```
Great, this created a new file `flake.nix` which is like a recipe that tells nix how to build our python project or how to assemble a development environment for it.
By modifying this file, we can tweak settings and change the way our package gets built by nix. But for now we just go with the defaults.

{{#include ../define-targets.md}}

## List the available packages
Let's get an overview of what the `flake.nix` allows us to do with our project.
```command
> nix flake show
warning: Git tree '/tmp/my_project' is dirty
warning: creating lock file '/tmp/my_project/flake.lock'
warning: Git tree '/tmp/my_project' is dirty
git+file:///tmp/my_project
└───packages
    └───x86_64-linux
        ├───main: package 'main'
        └───resolveImpure: package 'resolve'
```

What we can observe here:
1. ```warning: Git tree '/tmp/my_project' is dirty```
Nix warns us that the current git repo has uncommited changes. Thats fine, because we like to experiment for now. This warning will go away as soon as we commit our changes.
1. `warning: creating lock file '/tmp/my_project/flake.lock'`
Our flake.nix imported external libraries. The versions of these libraries have now been locked inside a new file `flake.lock`. We should later commit this file to the repo, in order to allow others to reproduce our build exactly.
1.
    ```
      git+file:///tmp/my_project
      └───packages
          └───x86_64-linux
              ├───main: package 'main'
              └───resolveImpure: package 'resolve'
    ```
    Similar like a .json file defines a structure of data, our flake.nix defines a structure of `nix attributes` which are things that we can build or run with nix.
    We can see that it contains packages for my current platform `x86_64-linux`.

    The packages which we can see here is my python package and a package called `resolveImpure`, which is a special package provided by dream2nix which we will learn more about later.

## Build the project
Let's try building our project.
If you get an error about `unresolved impurities`, see [Resolve Impurities](#resolve-impurities)
```command
> nix build .#main
```
Congratulations, your build artifacts will now be accessible via the `./result` directory. If your project contains executables, you can run these via `./result/bin/executable-name`.
If you want to develop on your python project, see [Create a development shell](#create-a-development-shell)

## Create a development shell
Nix can provide you with a development shell containing all your project's dependencies.
First, ensure that your project [is resolved](#resolve-impurities), then execute the following command.
```command
> nix develop -c $SHELL
```
The `-c $SHELL` part is only necessary if you use a different shell than bash and would like to bring that shell with you into the dev environment.

## Resolve impurities
If you try to build, you might run into the following error.
```command
> nix build .#main
error: The python package main contains unresolved impurities.
       Resolve by running the .resolve attribute of this derivation
       or by resolving all impure projects by running the `resolveImpure` package
```
Oops. It seems like our project does not contain enough information for dream2nix to construct a reproducible build. But this is not a problem as we can fix this by using the `resolveImpure` package that dream2nix provides.
```command
> nix run .#resolveImpure
...
adding file to git: dream2nix-packages/main/dream-lock.json
```
Fine, that created a new file `dream-lock.json` which is a lock file specifically for our python project. If we later add any dependencies, we will have to re-run `resolveImpure` to update this lock file.

Now everything should be ready to [Build the Project](#build-the-project)
