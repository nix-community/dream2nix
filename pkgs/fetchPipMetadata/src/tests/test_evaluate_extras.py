import pytest
from packaging.requirements import Requirement

import lock_file_from_report as l


@pytest.fixture
def env():
    return dict(python_version="3.10")


def test_marker_match(env):
    env = dict(python_version="3.10")
    requirement = Requirement("requests; python_version == '3.10'")
    assert l.evaluate_extras(requirement, None, env) == True


def test_marker_mismatch(env):
    env = dict(python_version="3.10")
    requirement = Requirement("requests; python_version == '3.11'")
    assert l.evaluate_extras(requirement, None, env) == False


def test_marker_extra_match(env):
    requirement = Requirement("requests; extra == 'security'")
    extras = ["security"]
    assert l.evaluate_extras(requirement, extras, {}) == True


def test_marker_extra_mismatch(env):
    requirement = Requirement("requests; extra == 'security'")
    extras = []
    assert l.evaluate_extras(requirement, extras, {}) == False
