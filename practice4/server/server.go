package main

import (
    "context"
    "crypto/tls"
    "crypto/x509"
    "log"
    "net"
    "os"
    "os/signal"
    "syscall"
    "time"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials"
    "google.golang.org/grpc/peer"
    "google.golang.org/grpc/status"
    "python_go_grpc/server/api"
)

func loggingInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo,
    handler grpc.UnaryHandler) (interface{}, error) {
    start := time.Now()
    response, err := handler(ctx, req)
    remote, _ := peer.FromContext(ctx)
    log.Printf("peer=%v method=%s status=%s duration=%s", remote.Addr,
        info.FullMethod, status.Code(err), time.Since(start))
    return response, err
}

func main() {
    certificate, err := tls.LoadX509KeyPair("certs/server.pem", "certs/server-key.pem")
    if err != nil { log.Fatal(err) }
    ca, err := os.ReadFile("certs/ca.pem")
    if err != nil { log.Fatal(err) }
    pool := x509.NewCertPool()
    if !pool.AppendCertsFromPEM(ca) { log.Fatal("invalid CA certificate") }
    tlsConfig := &tls.Config{MinVersion: tls.VersionTLS12,
        Certificates: []tls.Certificate{certificate}, ClientCAs: pool,
        ClientAuth: tls.RequireAndVerifyClientCert}
    secure := grpc.NewServer(grpc.Creds(credentials.NewTLS(tlsConfig)),
        grpc.UnaryInterceptor(loggingInterceptor))
    plain := grpc.NewServer(grpc.UnaryInterceptor(loggingInterceptor))
    api.RegisterDiceServiceServer(secure, api.NewServer())
    api.RegisterDiceServiceServer(plain, api.NewServer())
    for address, server := range map[string]*grpc.Server{
        "127.0.0.1:8443": secure, "127.0.0.1:50051": plain,
    } {
        listener, err := net.Listen("tcp", address)
        if err != nil { log.Fatal(err) }
        log.Printf("Starting gRPC server address=%s", address)
        go func(s *grpc.Server, l net.Listener) {
            if err := s.Serve(l); err != nil { log.Print(err) }
        }(server, listener)
    }
    signals := make(chan os.Signal, 1)
    signal.Notify(signals, syscall.SIGINT, syscall.SIGTERM)
    <-signals
    secure.GracefulStop()
    plain.GracefulStop()
}
