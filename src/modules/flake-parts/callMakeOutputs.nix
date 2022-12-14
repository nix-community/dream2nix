/*
This adapter is needed because our interface diverges from what `makeOutputs`
accepts.
# TODO: remove this adapter and change makeOutputs to acceppt the new style
  of arguments directly.
*/
{
  lib,
  makeOutputs,
}: input: let
  l = lib // builtins;

  mkProject = project:
    (l.removeAttrs project ["translatorArgs"])
    // {
      subsystemInfo = project.translatorArgs.${project.translator};
    };

  finalProjects = l.mapAttrs (_: mkProject) input.projects;

  makeOutputsArgs = {
    inherit
      (input)
      source
      pname
      settings
      packageOverrides
      sourceOverrides
      inject
      ;
    projects = finalProjects;
  };
in
  makeOutputs makeOutputsArgs
