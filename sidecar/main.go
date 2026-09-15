// gw-dns sidecar: turns %gw-dns requests into A records.
//
// It subscribes to /requests on the sponsor's %gw-dns agent, writes
// each request's domain to the DNS backend, and pokes %dns-complete
// back. It holds no state of its own: the agent replays every
// pending request on each new subscription, and Upsert is idempotent.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"
)

const app = "gw-dns"

type request struct {
	Ship    string   `json:"ship"`
	Address string   `json:"address"`
	Domain  string   `json:"domain"`
	Turf    []string `json:"turf"`
}

type complete struct {
	Ship    string   `json:"ship"`
	Address string   `json:"address"`
	Turf    []string `json:"turf"`
}

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("%s is not set", key)
	}
	return v
}

func main() {
	log.SetFlags(log.LstdFlags | log.LUTC)
	base := env("URBIT_URL", "http://localhost:80")
	ship := mustEnv("URBIT_SHIP")
	code := mustEnv("URBIT_CODE")
	zone := env("DNS_ZONE", "groundwire.me")

	var backend Backend
	switch kind := env("DNS_BACKEND", "log"); kind {
	case "log":
		backend = logBackend{}
	case "do":
		backend = newDOBackend(zone, mustEnv("DO_TOKEN"))
	default:
		log.Fatalf("unknown DNS_BACKEND %q (want log or do)", kind)
	}
	log.Printf("gw-dns sidecar: %s on %s, zone %s, backend %s", ship, base, zone, env("DNS_BACKEND", "log"))

	// bind writes one request's record. it is the whole job.
	bind := func(ev Event) (*request, error) {
		var req request
		if err := json.Unmarshal(ev.Data, &req); err != nil {
			return nil, fmt.Errorf("bad request %s: %w", ev.Data, err)
		}
		if !strings.HasSuffix(req.Domain, "."+zone) {
			log.Printf("leaving %s for %s pending: not under %s", req.Domain, req.Ship, zone)
			return nil, nil
		}
		log.Printf("request: %s -> %s A %s", req.Ship, req.Domain, req.Address)
		if err := backend.Upsert(req.Domain, req.Address); err != nil {
			return nil, fmt.Errorf("upsert %s: %w", req.Domain, err)
		}
		return &req, nil
	}

	ctx := context.Background()
	delay := time.Second
	for {
		err := run(ctx, base, ship, code, func(ev Event, e *Eyre) error {
			req, err := bind(ev)
			if err != nil || req == nil {
				return err
			}
			done := complete{Ship: req.Ship, Address: req.Address, Turf: req.Turf}
			if err := e.Poke(app, "dns-complete", done); err != nil {
				return fmt.Errorf("poke dns-complete for %s: %w", req.Ship, err)
			}
			log.Printf("completed %s as %s", req.Ship, req.Domain)
			return nil
		})
		log.Printf("stream ended: %v; reconnecting in %s", err, delay)
		time.Sleep(delay)
		if delay < time.Minute {
			delay *= 2
		}
	}
}

// run logs in, opens a fresh channel and subscription, and reads
// facts until the stream drops.
func run(ctx context.Context, base, ship, code string, handle func(Event, *Eyre) error) error {
	e, err := NewEyre(base, ship, code)
	if err != nil {
		return err
	}
	if err := e.Login(); err != nil {
		return err
	}
	if err := e.Subscribe(app, "/requests"); err != nil {
		return err
	}
	return e.Stream(ctx, func(ev Event) error { return handle(ev, e) })
}
