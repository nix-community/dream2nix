import pytest
import lock_file_from_report as l
from pathlib import Path


def test_wrong_prefix():
    assert l.path_from_file_url("http://") == None


def test_relative_path():
    url = "file://foo/bar"
    expected = Path("./foo/bar").absolute()
    assert l.path_from_file_url(url) == expected


def test_absolute_path():
    url = "file:///foo/bar"
    expected = Path("/foo/bar")
    assert l.path_from_file_url(url) == expected
