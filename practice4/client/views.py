"""Web views for two gRPC communication paths."""
import grpc
from django.http import HttpResponse
from django.shortcuts import render
from .api.client import roll_die

ICONS = ["?", "⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
DIRECT = "127.0.0.1:8443"
PROXY = "127.0.0.1:9448"

def index(request):
    """Roll two independent dice through direct TLS and nginx."""
    a = b = 0
    error = ""
    if request.method == "POST":
        try:
            a, b = roll_die(DIRECT), roll_die(PROXY)
        except grpc.RpcError as exc:
            error = f"gRPC unavailable: {exc.code().name}"
    return render(request, "index.html", {"a": a, "b": b, "icon_a": ICONS[a],
        "icon_b": ICONS[b], "sign": "=" if a == b else "<" if a < b else ">",
        "error": error}, status=502 if error else 200)

def result(address):
    """Return a die value, or a controlled gateway error."""
    try:
        value = roll_die(address)
        return HttpResponse(f"Value: {value} {ICONS[value]}", content_type="text/plain; charset=utf-8")
    except grpc.RpcError as exc:
        return HttpResponse(f"gRPC unavailable: {exc.code().name}", status=502)

def direct(_request):
    """Call the Go server directly with mTLS."""
    return result(DIRECT)

def proxy(_request):
    """Call the Go server through nginx with mTLS."""
    return result(PROXY)
