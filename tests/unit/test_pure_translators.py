import nix_ffi
import os
import pytest


def get_projects_to_test():
  tests = nix_ffi.eval(
    'framework.translators',
    wrapper_code = '''
      {result, ...}: let
        lib = (import <nixpkgs> {}).lib;
        l = lib // builtins;
      in
        l.flatten (
          l.map
          (
            translator:
              l.map
                (source: {
                  source = l.toString source;
                  translator = translator.name;
                  inherit (translator) subsystem type;
                })
                (translator.generateUnitTestsForProjects or [])
          )
          (l.attrValues result)
        )
    ''',
  )
  result = []
  for test in tests:
    if test['type'] == 'all':
      continue
    result.append(dict(
      project = dict(
        name="test",
        relPath="",
        translator=test['translator'],
        subsystemInfo={},
      ),
      translator=test['translator'],
      source = test['source'],
      subsystem = test['subsystem'],
      type = test['type'],
    ))
  return result


projects = get_projects_to_test()


def check_format_dependencies(dependencies):
  assert isinstance(dependencies, list)
  for dep in dependencies:
    assert set(dep.keys()) == {'name', 'version'}
    assert isinstance(dep['name'], str)
    assert len(dep['name']) > 0
    assert isinstance(dep['version'], str)
    assert len(dep['version']) > 0

def check_format_sourceSpec(sourceSpec):
  assert isinstance(sourceSpec, dict)
  assert 'type' in sourceSpec

@pytest.mark.parametrize("p", projects)
def test_packageName(p):
  defaultPackage = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.defaultPackage
    ''',
  )
  assert isinstance(defaultPackage, str)
  assert len(defaultPackage) > 0

@pytest.mark.parametrize("p", projects)
def test_exportedPackages(p):
  exportedPackages = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.exportedPackages
    ''',
  )
  assert isinstance(exportedPackages, dict)
  assert len(exportedPackages) > 0

@pytest.mark.parametrize("p", projects)
def test_extraObjects(p):
  extraObjects = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.extraObjects
    ''',
  )
  assert isinstance(extraObjects, list)
  for extra_obj in extraObjects:
    assert set(extra_obj.keys()) == \
      {'name', 'version', 'dependencies', 'sourceSpec'}
    assert isinstance(extra_obj['name'], str)
    assert len(extra_obj['name']) > 0
    assert isinstance(extra_obj['version'], str)
    assert len(extra_obj['version']) > 0
    check_format_dependencies(extra_obj['dependencies'])
    check_format_sourceSpec(extra_obj['sourceSpec'])

@pytest.mark.parametrize("p", projects)
def test_location(p):
  location = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.location
    ''',
  )
  assert isinstance(location, str)

@pytest.mark.parametrize("p", projects)
def test_serializedRawObjects(p):
  serializedRawObjects = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, lib, ...}:
      let
        len = lib.length result.inputs.serializedRawObjects;
      in
        # for performance reasons check only first/last 10 items of the list
        (lib.sublist 0 10 result.inputs.serializedRawObjects)
        ++ (lib.sublist (lib.max (len - 10) 0) len result.inputs.serializedRawObjects)
    ''',
  )
  assert isinstance(serializedRawObjects, list)
  assert len(serializedRawObjects) > 0
  for raw_obj in serializedRawObjects:
    assert isinstance(raw_obj, dict)

@pytest.mark.parametrize("p", projects)
def test_subsystemName(p):
  subsystemName = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.subsystemName
    ''',
  )
  assert isinstance(subsystemName, str)
  assert len(subsystemName) > 0

@pytest.mark.parametrize("p", projects)
def test_subsystemAttrs(p):
  subsystemAttrs = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      builtins.trace result.inputs.subsystemAttrs
      result.inputs.subsystemAttrs
    ''',
  )
  assert isinstance(subsystemAttrs, dict)

@pytest.mark.parametrize("p", projects)
def test_translatorName(p):
  translatorName = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, ...}:
      result.inputs.translatorName
    ''',
  )
  assert isinstance(translatorName, str)
  assert len(translatorName) > 0

@pytest.mark.parametrize("p", projects)
def test_extractors(p):
  finalObjects = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, dlib, ...}:
      let
        l = builtins;
        inputs = result.inputs;
        rawObjects = inputs.serializedRawObjects;
        s = dlib.simpleTranslate2;

        finalObjects = s.mkFinalObjects rawObjects inputs.extractors;
        allDependencies = s.makeDependencies finalObjects;
        exportedFinalObjects =
          s.mkExportedFinalObjects finalObjects inputs.exportedPackages;
        relevantFinalObjects =
          s.mkRelevantFinalObjects exportedFinalObjects allDependencies;
      in
        relevantFinalObjects ++ (inputs.extraObjects or [])
    ''',
  )
  assert isinstance(finalObjects, list)
  assert len(finalObjects) > 0
  for finalObj in finalObjects:
    assert (set(finalObj.keys()) - {'rawObj', 'key'}) == \
      {'name', 'version', 'sourceSpec', 'dependencies'}
    check_format_dependencies(finalObj['dependencies'])
    check_format_sourceSpec(finalObj['sourceSpec'])

@pytest.mark.parametrize("p", projects)
def test_keys(p):
  objectsByKey = nix_ffi.eval(
    f"framework.translatorsBySubsystem.{p['subsystem']}.{p['translator']}.translateInstanced",
    params=dict(
      project=p['project'],
      source=p['source'],
    ),
    wrapper_code = '''
      {result, dlib, ...}:
      let
        l = builtins;
        inputs = result.inputs;
        rawObjects = inputs.serializedRawObjects;
        s = dlib.simpleTranslate2;

        finalObjects = s.mkFinalObjects rawObjects inputs.extractors;
        allDependencies = s.makeDependencies finalObjects;
        exportedFinalObjects =
          s.mkExportedFinalObjects finalObjects inputs.exportedPackages;
        relevantFinalObjects =
          s.mkRelevantFinalObjects exportedFinalObjects allDependencies;

        objectsByKey =
          l.mapAttrs
          (key: keyFunc:
            l.foldl'
            (merged: finalObj:
              merged
              // {"${keyFunc finalObj.rawObj finalObj}" = finalObj;})
            {}
            relevantFinalObjects)
          inputs.keys;
      in
        objectsByKey
    ''',
  )
  assert isinstance(objectsByKey, dict)
  for key_name, objects in objectsByKey.items():
    for finalObj in objects.values():
      assert set(finalObj.keys()) - {'rawObj', 'key'} == \
        {'name', 'version', 'sourceSpec', 'dependencies'}
      check_format_dependencies(finalObj['dependencies'])
      check_format_sourceSpec(finalObj['sourceSpec'])
