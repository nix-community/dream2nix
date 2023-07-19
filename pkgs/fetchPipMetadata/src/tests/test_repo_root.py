import os
import pytest
from packaging.requirements import Requirement
from pathlib import Path
from tempfile import TemporaryDirectory

import lock_file_from_report as l


def test_not_in_repo():
    with TemporaryDirectory() as tmpdir:
        assert l.repo_root(str(tmpdir)) == str(Path(".").absolute())


def test_in_repo_root(git_repo_path):
    assert l.repo_root(git_repo_path) == str(git_repo_path)
