def normalizeWorkspaceDep:
  if ($workspaceAttrs."dependencies"."\(.key)" | type) == "object"
  then [.value, $workspaceAttrs."dependencies"."\(.key)"] | add
  else [.value, {"version":$workspaceAttrs."dependencies"."\(.key)"}] | add
  end
  # remove workspace option from the dependency
  | del(.workspace)
;

# normalizes workspace inherited dependencies for one list
def mapWorkspaceDepsFor(name):
  if has(name)
  then
    ."\(name)" = (
      ."\(name)"
      | to_entries
      | map(
        if (.value | type) == "object" and .value.workspace == true
        then .value = (. | normalizeWorkspaceDep)
        else .
        end
      )
      | from_entries
    )
  else .
  end
;

# shorthand for normalizing all the dependencies list
def mapWorkspaceDeps:
  mapWorkspaceDepsFor("dependencies")
  | mapWorkspaceDepsFor("dev-dependencies")
  | mapWorkspaceDepsFor("build-dependencies")
;

# normalizes workpsace inherited package attributes
def mapWorkspaceAttrs(name):
  if has(name)
  then
    ."\(name)" = (
      ."\(name)"
      | to_entries
      | map(
        if (.value | type) == "object" and .value.workspace == true
        then .value = $workspaceAttrs."\(name)"."\(.key)"
        else .
        end
      )
      | from_entries
    )
  else .
  end
;

# normalize workspace inherited deps and attributes
mapWorkspaceDeps
| mapWorkspaceAttrs("package")
| if has("target")
  then
    # normalize workspace inherited deps in target specific deps
    .target = (
      .target
      | to_entries
      | map(.value = (.value | mapWorkspaceDeps))
      | from_entries
    )
  else .
  end
