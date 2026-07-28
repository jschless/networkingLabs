from pathlib import Path

from pipeline.core import assert_lab_repo


def test_disposable_repository_boundary():
    assert Path.cwd() == Path("/workspace/lab-repo")
    assert_lab_repo()
