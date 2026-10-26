"""End-to-end checks against the running services."""
import concurrent.futures
import os
import re
import unittest
import urllib.request
import grpc
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "client.settings")
import django
django.setup()
from django.test import Client as WebClient
from client.api.client import roll_die

class IntegrationTests(unittest.TestCase):
    """Verify successful calls and rejection of unauthenticated clients."""
    def test_01_direct_mtls(self):
        values = [roll_die("127.0.0.1:8443") for _ in range(20)]
        self.assertTrue(all(1 <= value <= 6 for value in values))
        print("DIRECT mTLS: 20 valid rolls", values)

    def test_02_nginx_mtls(self):
        values = [roll_die("127.0.0.1:9448") for _ in range(20)]
        self.assertTrue(all(1 <= value <= 6 for value in values))
        print("NGINX mTLS: 20 valid rolls", values)

    def test_03_no_certificate_rejected(self):
        for target in ("127.0.0.1:8443", "127.0.0.1:9448"):
            with self.subTest(target=target):
                with self.assertRaises(grpc.RpcError):
                    roll_die(target, with_certificate=False)
                print("REJECTED without client certificate:", target)

    def test_04_concurrent_clients(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            values = list(pool.map(roll_die, ["127.0.0.1:8443", "127.0.0.1:9448"] * 20))
        self.assertTrue(all(1 <= value <= 6 for value in values))
        print("CONCURRENT: 40 valid rolls, 8 workers")

    def test_05_web_routes_and_post(self):
        client = WebClient(enforce_csrf_checks=True)
        response = client.get("/")
        self.assertEqual(response.status_code, 200)
        token = client.cookies["csrftoken"].value
        response = client.post("/", {"csrfmiddlewaretoken": token})
        self.assertEqual(response.status_code, 200)
        self.assertNotIn(b"gRPC unavailable", response.content)
        for route in ("/grpc", "/nginx"):
            response = client.get(route)
            self.assertEqual(response.status_code, 200)
            self.assertRegex(response.content.decode(), r"Value: [1-6]")
        print("DJANGO: GET /, POST / with CSRF, GET /grpc, GET /nginx = 200")

    def test_06_multiple_web_clients(self):
        for port in (8000, 8001, 8002):
            for route in ("/grpc", "/nginx"):
                with urllib.request.urlopen(f"http://127.0.0.1:{port}{route}", timeout=10) as response:
                    text = response.read().decode()
                    self.assertEqual(response.status, 200)
                    self.assertIsNotNone(re.search(r"Value: [1-6]", text))
                    print(f"HTTP {port}{route}: {text}")

if __name__ == "__main__":
    unittest.main(verbosity=2)
