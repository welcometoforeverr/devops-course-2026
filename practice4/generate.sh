#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p client/api server/api
python -m grpc_tools.protoc -I proto --python_out=client/api \
  --grpc_python_out=client/api proto/api.proto
python - <<'PY'
from pathlib import Path
p = Path("client/api/api_pb2_grpc.py")
s = p.read_text().replace("import api_pb2 as api__pb2", "from . import api_pb2 as api__pb2")
p.write_text(s)
PY
export PATH="$(go env GOPATH)/bin:$PATH"
go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.36.5
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
python -m grpc_tools.protoc -I proto --go_out=. --go_opt=module=python_go_grpc \
  --go-grpc_out=. --go-grpc_opt=module=python_go_grpc proto/api.proto
go mod tidy
gofmt -w server
go build -o dice-server ./server
