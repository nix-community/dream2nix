import django
import lxml
import psycopg2

__version__ = "1.0"


def hello():
    print(f"{__file__}: Hello world!")
    print(f"{django.get_version()=}")
    print(f"{lxml.__version__=}")
    print(f"{psycopg2.__version__=}")
