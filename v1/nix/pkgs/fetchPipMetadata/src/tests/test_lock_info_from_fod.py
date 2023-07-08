import pytest
import lock_file_from_report as l


@pytest.fixture
def drv_json():
    return dict(
        env=dict(
            urls="https://example.com",
        ),
        outputs=dict(
            out=dict(
                hash="xxx",
                hashAlgo="r:sha256",
                path="blablub",
            )
        ),
    )


def test_bad_store_path(drv_json):
    with pytest.raises(AssertionError):
        store_path = ""
        l.lock_info_from_fod(store_path, drv_json)


def test_valid_store_path(drv_json):
    store_path = "blablub"
    l.lock_info_from_fod(store_path, drv_json)
