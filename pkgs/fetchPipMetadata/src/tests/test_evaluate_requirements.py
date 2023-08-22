import pytest
from packaging.requirements import Requirement

import lock_file_from_report as l


def test_noop():
    result = l.evaluate_requirements(
        env={},
        reqs=dict(
            root_package={Requirement("requests")},
            requests=set(),
        ),
        dependencies=dict(),
        root_name="root_package",
        extras=None,
        seen=[],
    )
    assert result == dict(
        root_package={"requests"},
        requests=set(),
    )


def test_extra_not_selected():
    result = l.evaluate_requirements(
        env={},
        reqs=dict(
            root_package={Requirement("requests; extra == 'http'")},
            requests=set(),
        ),
        dependencies=dict(),
        root_name="root_package",
        extras=None,
        seen=[],
    )
    assert result == dict(root_package=set())


def test_extra_selected():
    result = l.evaluate_requirements(
        env={},
        reqs=dict(
            root_package={Requirement("requests; extra == 'http'")},
            requests=set(),
        ),
        dependencies=dict(),
        root_name="root_package",
        extras=["http"],
        seen=[],
    )
    assert result == dict(
        root_package={"requests"},
        requests=set(),
    )


def test_platform_mismatch():
    result = l.evaluate_requirements(
        env=dict(sys_platform="linux"),
        reqs=dict(
            root_package={Requirement("requests; sys_platform == 'darwin'")},
            requests=set(),
        ),
        dependencies=dict(),
        root_name="root_package",
        extras=None,
        seen=[],
    )
    assert result == dict(root_package=set())


def test_cycle():
    result = l.evaluate_requirements(
        env={},
        reqs=dict(
            root_package={Requirement("foo")},
            foo={Requirement("bar")},
            bar={Requirement("foo")},
        ),
        dependencies=dict(),
        root_name="root_package",
        extras=None,
        seen=[],
    )
    assert result == dict(
        root_package={"foo"},
        foo={"bar"},
        bar=set(),
    )
