import pytest
import lock_file_from_report as l


@pytest.fixture
def store_path():
    return "blablub"


@pytest.fixture
def drv_json(store_path):
    return dict(
        env=dict(
            urls="https://example.com",
        ),
        outputs=dict(
            out=dict(
                hash="xxx",
                hashAlgo="r:sha256",
                path=store_path,
            )
        ),
    )


def test_mismatching_store_path(drv_json):
    with pytest.raises(AssertionError):
        store_path = ""
        l.lock_info_from_fod(store_path, drv_json)


def test_matching_store_path(store_path, drv_json):
    l.lock_info_from_fod(store_path, drv_json)


def test_no_fod(store_path, drv_json):
    drv_json["env"]["urls"] = ""
    drv_json["outputs"]["out"]["hash"] = ""
    with pytest.raises(Exception):
        l.lock_info_from_fod(store_path, drv_json)


def test_invalid_drv(store_path):
    with pytest.raises(AssertionError):
        l.lock_info_from_fod(store_path, {})
