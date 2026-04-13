"""
Integration test: reading Rds file from HTTP server via BytesIO.
Uses Python's built-in http.server - no external dependencies.

Run with: python tests/test_http_integration.py --inplace
"""
import io
import os
import threading
import unittest
import urllib.request
import warnings
from contextlib import contextmanager
from http.server import HTTPServer, SimpleHTTPRequestHandler


@contextmanager
def http_server(directory):
    """Context manager that runs an HTTP server serving files from directory."""
    class QuietHandler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=directory, **kwargs)
        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), QuietHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_address[1]}"
    finally:
        server.shutdown()
        server.server_close()


class TestHttpIntegration(unittest.TestCase):

    def setUp(self):
        warnings.simplefilter("ignore", category=RuntimeWarning)

    def test_read_rds_from_http(self):
        """Test reading Rds file from local HTTP server (simulates remote URL)."""
        data_folder = os.path.join(os.path.dirname(__file__), "..", "test_data", "basic")

        with http_server(data_folder) as base_url:
            url = f"{base_url}/one.Rds"
            with urllib.request.urlopen(url) as response:
                res = pyreadr.read_r(io.BytesIO(response.read()))

            df = res[None]
            self.assertEqual(len(df), 6, f"Expected 6 rows, got {len(df)}")
            self.assertEqual(len(df.columns), 7, f"Expected 7 columns, got {len(df.columns)}")

    def test_download_file_from_http(self):
        """Test download_file with local HTTP server, then read the downloaded file."""
        data_folder = os.path.join(os.path.dirname(__file__), "..", "test_data", "basic")
        write_folder = os.path.join(os.path.dirname(__file__), "..", "test_data", "write")
        dest_path = os.path.join(write_folder, "downloaded_one.Rds")

        with http_server(data_folder) as base_url:
            url = f"{base_url}/one.Rds"
            result_path = pyreadr.download_file(url, dest_path)

        self.assertEqual(result_path, dest_path)
        self.assertTrue(os.path.isfile(dest_path))

        res = pyreadr.read_r(dest_path)
        df = res[None]
        self.assertEqual(len(df), 6, f"Expected 6 rows, got {len(df)}")
        self.assertEqual(len(df.columns), 7, f"Expected 7 columns, got {len(df.columns)}")

        os.remove(dest_path)

    def test_read_rdata_from_http(self):
        """Test reading RData file from local HTTP server (simulates remote URL)."""
        data_folder = os.path.join(os.path.dirname(__file__), "..", "test_data", "basic")

        with http_server(data_folder) as base_url:
            url = f"{base_url}/two.RData"
            with urllib.request.urlopen(url) as response:
                res = pyreadr.read_r(io.BytesIO(response.read()))

            self.assertIn('df1', res)
            self.assertIn('df2', res)
            self.assertEqual(len(res['df1']), 6, f"Expected 6 rows, got {len(res['df1'])}")


if __name__ == '__main__':

    import sys

    if "--inplace" in sys.argv:

        script_folder = os.path.split(os.path.split(os.path.realpath(__file__))[0])[0]
        sys.path.insert(0, script_folder)
        sys.argv.remove('--inplace')

    import pyreadr

    print("package location:", pyreadr.__file__)

    unittest.main()
