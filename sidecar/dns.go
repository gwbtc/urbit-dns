package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Backend writes one A record. Upsert must be idempotent: the agent
// replays every pending request whenever the sidecar reconnects.
type Backend interface {
	Upsert(fqdn, ip string) error
}

// logBackend only prints, for running the pipeline without a zone.
type logBackend struct{}

func (logBackend) Upsert(fqdn, ip string) error {
	log.Printf("dns (log): %s A %s", fqdn, ip)
	return nil
}

// doBackend writes to a DigitalOcean DNS zone.
type doBackend struct {
	zone  string
	token string
	http  *http.Client
}

type doRecord struct {
	ID   int64  `json:"id,omitempty"`
	Type string `json:"type"`
	Name string `json:"name"`
	Data string `json:"data"`
	TTL  int    `json:"ttl,omitempty"`
}

func newDOBackend(zone, token string) *doBackend {
	return &doBackend{zone: zone, token: token, http: &http.Client{Timeout: 30 * time.Second}}
}

func (d *doBackend) do(method, path string, body any, out any) error {
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, "https://api.digitalocean.com/v2"+path, rdr)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+d.token)
	req.Header.Set("Content-Type", "application/json")
	resp, err := d.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("digitalocean %s %s: %s: %s", method, path, resp.Status, bytes.TrimSpace(raw))
	}
	if out != nil && len(raw) > 0 {
		return json.Unmarshal(raw, out)
	}
	return nil
}

// Upsert creates the A record for fqdn or points the existing one at ip.
func (d *doBackend) Upsert(fqdn, ip string) error {
	name := strings.TrimSuffix(fqdn, "."+d.zone)
	if name == fqdn {
		return fmt.Errorf("%s is not under zone %s", fqdn, d.zone)
	}
	var listing struct {
		Records []doRecord `json:"domain_records"`
	}
	q := url.Values{"type": {"A"}, "name": {fqdn}, "per_page": {"200"}}
	if err := d.do("GET", "/domains/"+d.zone+"/records?"+q.Encode(), nil, &listing); err != nil {
		return err
	}
	for _, r := range listing.Records {
		if r.Type != "A" || r.Name != name {
			continue
		}
		if r.Data == ip {
			log.Printf("dns: %s A %s already set", fqdn, ip)
			return nil
		}
		path := fmt.Sprintf("/domains/%s/records/%d", d.zone, r.ID)
		if err := d.do("PATCH", path, map[string]string{"data": ip}, nil); err != nil {
			return err
		}
		log.Printf("dns: %s A %s -> %s", fqdn, r.Data, ip)
		return nil
	}
	rec := doRecord{Type: "A", Name: name, Data: ip, TTL: 60}
	if err := d.do("POST", "/domains/"+d.zone+"/records", map[string]any{
		"type": rec.Type, "name": rec.Name, "data": rec.Data, "ttl": rec.TTL,
	}, nil); err != nil {
		return err
	}
	log.Printf("dns: created %s A %s", fqdn, ip)
	return nil
}
