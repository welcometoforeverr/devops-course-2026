"""Mutually authenticated gRPC client."""
from pathlib import Path
import grpc
from . import api_pb2, api_pb2_grpc

CERTS = Path(__file__).resolve().parents[2] / "certs"

def roll_die(address, with_certificate=True):
    """Call RollDie with certificate verification and a finite deadline."""
    credentials = grpc.ssl_channel_credentials(
        root_certificates=(CERTS / "ca.pem").read_bytes(),
        private_key=(CERTS / "client-key.pem").read_bytes() if with_certificate else None,
        certificate_chain=(CERTS / "client.pem").read_bytes() if with_certificate else None,
    )
    with grpc.secure_channel(address, credentials) as channel:
        response = api_pb2_grpc.DiceServiceStub(channel).RollDie(
            api_pb2.RollDieRequest(), timeout=5)
    return response.value
