package api

import (
    "context"
    "sync"
    "testing"
)

func TestConcurrentRolls(t *testing.T) {
    server := NewServer()
    var wg sync.WaitGroup
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            response, err := server.RollDie(context.Background(), &RollDieRequest{})
            if err != nil || response.Value < 1 || response.Value > 6 {
                t.Errorf("invalid result: %v, %v", response, err)
            }
        }()
    }
    wg.Wait()
}
