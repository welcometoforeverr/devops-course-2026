package api

import (
    "context"
    "math/rand"
    "sync"
    "time"
)

// Server protects its random source during concurrent RPC calls.
type Server struct {
    UnimplementedDiceServiceServer
    mu sync.Mutex
    rnd *rand.Rand
}

func NewServer() *Server {
    return &Server{rnd: rand.New(rand.NewSource(time.Now().UnixNano()))}
}

func (s *Server) RollDie(_ context.Context, _ *RollDieRequest) (*RollDieResponse, error) {
    s.mu.Lock()
    value := s.rnd.Intn(6) + 1
    s.mu.Unlock()
    return &RollDieResponse{Value: int32(value)}, nil
}
