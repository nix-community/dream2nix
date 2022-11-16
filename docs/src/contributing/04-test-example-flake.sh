# inspect if your subsystem exports any package/devShell
nix flake show $myFlake --override-input dream2nix $dream2nix --show-trace

# run your translator and dump the dream-lock.json for inspection
nix run $myFlake#default.resolve --override-input dream2nix $dream2nix --show-trace

# test if the default package builds
nix build $myFlake#default --override-input dream2nix $dream2nix --show-trace
