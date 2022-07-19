{pkgs, ...}:
pkgs.apt.overrideDerivation (oldAttrs: {patches = [./apt.patch];})
