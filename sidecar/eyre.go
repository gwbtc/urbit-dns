package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

// Eyre is a minimal client for one urbit ship's HTTP api: login with
// +code, one channel, subscribe, poke, and an SSE reader that acks.
type Eyre struct {
	base   string // http://host:port
	ship   string // without the leading sigil
	code   string
	http   *http.Client
	chanID string
	seq    atomic.Int64
}

// Event is one %fact from a subscription.
type Event struct {
	ID   int64
	Data json.RawMessage
}

type channelResponse struct {
	ID       int64           `json:"id"`
	Response string          `json:"response"`
	OK       string          `json:"ok"`
	Err      string          `json:"err"`
	JSON     json.RawMessage `json:"json"`
}

func NewEyre(base, ship, code string) (*Eyre, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, err
	}
	return &Eyre{
		base: strings.TrimRight(base, "/"),
		ship: strings.TrimPrefix(ship, "~"),
		code: code,
		http: &http.Client{Jar: jar},
	}, nil
}

func (e *Eyre) next() int64 { return e.seq.Add(1) }

// Login posts +code and keeps the auth cookie in the jar.
func (e *Eyre) Login() error {
	form := url.Values{"password": {e.code}}
	req, err := http.NewRequest("POST", e.base+"/~/login", strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := e.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	if resp.StatusCode/100 != 2 && resp.StatusCode != 303 && resp.StatusCode != 302 {
		return fmt.Errorf("login: status %s", resp.Status)
	}
	for _, c := range e.http.Jar.Cookies(req.URL) {
		if strings.HasPrefix(c.Name, "urbauth-") {
			return nil
		}
	}
	return errors.New("login: no urbauth cookie set")
}

// put sends a batch of actions to the channel, opening it on first use.
func (e *Eyre) put(actions []map[string]any) error {
	if e.chanID == "" {
		e.chanID = strconv.FormatInt(time.Now().UnixNano(), 10)
	}
	body, err := json.Marshal(actions)
	if err != nil {
		return err
	}
	req, err := http.NewRequest("PUT", e.base+"/~/channel/"+e.chanID, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := e.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("channel put: status %s", resp.Status)
	}
	return nil
}

// Subscribe asks the channel for %facts on app's path.
func (e *Eyre) Subscribe(app, path string) error {
	return e.put([]map[string]any{{
		"id":     e.next(),
		"action": "subscribe",
		"ship":   e.ship,
		"app":    app,
		"path":   path,
	}})
}

// Poke sends a json poke to app with the given mark.
func (e *Eyre) Poke(app, mark string, data any) error {
	return e.put([]map[string]any{{
		"id":     e.next(),
		"action": "poke",
		"ship":   e.ship,
		"app":    app,
		"mark":   mark,
		"json":   data,
	}})
}

func (e *Eyre) ack(eventID int64) error {
	return e.put([]map[string]any{{
		"id":       e.next(),
		"action":   "ack",
		"event-id": eventID,
	}})
}

// Stream reads the channel's SSE stream until ctx ends or the
// connection drops, calling handle for every %fact. Every event is
// acked after handle returns, so a handler that fails should return
// an error to stop the stream and let the caller reconnect and replay.
func (e *Eyre) Stream(ctx context.Context, handle func(Event) error) error {
	req, err := http.NewRequestWithContext(ctx, "GET", e.base+"/~/channel/"+e.chanID, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "text/event-stream")
	resp, err := e.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode/100 != 2 {
		return fmt.Errorf("channel stream: status %s", resp.Status)
	}

	var id int64 = -1
	var data bytes.Buffer
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 64*1024), 16*1024*1024)
	for scanner.Scan() {
		line := scanner.Text()
		switch {
		case strings.HasPrefix(line, "id:"):
			id, _ = strconv.ParseInt(strings.TrimSpace(line[3:]), 10, 64)
		case strings.HasPrefix(line, "data:"):
			data.WriteString(strings.TrimSpace(line[5:]))
		case line == "":
			if data.Len() == 0 {
				continue
			}
			err := e.dispatch(id, data.Bytes(), handle)
			data.Reset()
			if err != nil {
				return err
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return err
	}
	return errors.New("channel stream closed")
}

func (e *Eyre) dispatch(id int64, raw []byte, handle func(Event) error) error {
	var msg channelResponse
	if err := json.Unmarshal(raw, &msg); err != nil {
		return fmt.Errorf("bad channel message: %w", err)
	}
	switch msg.Response {
	case "diff":
		if err := handle(Event{ID: id, Data: msg.JSON}); err != nil {
			return err
		}
	case "poke":
		if msg.Err != "" {
			log.Printf("poke %d failed: %s", msg.ID, msg.Err)
		}
	case "subscribe":
		if msg.Err != "" {
			return fmt.Errorf("subscribe %d failed: %s", msg.ID, msg.Err)
		}
		log.Printf("subscribed")
	case "quit":
		return errors.New("subscription quit")
	}
	if id >= 0 {
		return e.ack(id)
	}
	return nil
}
