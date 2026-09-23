# urbit-dns

The `%dns` desk binds Groundwire comets' IPv4 addresses to domains under
`groundwire.me`. It holds one Gall agent, `%gw-dns`, a fork of Urbit's
`%dns-collector`, and a stateless Go sidecar that writes the DNS records.

## How it works

1. A comet pokes the sponsor's `%gw-dns` with `%dns-address [%if .1.2.3.4]`,
   or the sponsor's operator pokes it with `%gw-dns-address [~comet %if ...]`
   (Causeway knows both the ship and the VPS address during onboarding).
2. The agent derives the comet's mnemonym and assigns the shortest domain
   nobody else holds: first and last word, then two from each end, and so on
   up to the whole nym, which is unique. `.bespoke.unnerved...hereby.kazoo`
   gets `bespoke.kazoo.groundwire.me` unless that is taken, then
   `bespoke.unnerved.hereby.kazoo.groundwire.me`, and so on.
3. The agent gives a `%gw-dns-request` fact on `/requests`. The sidecar,
   subscribed over Eyre, upserts the A record and pokes back `%dns-complete`.
4. The agent records the binding and gives `%dns-binding` on `/~comet`.

The sidecar keeps no state. Every new subscription to `/requests` replays
every pending request, and the upsert is idempotent.

Only comets get domains. Anything else is rejected.

### Reading the result

- `+dns!gw-dns/domain ~comet` prints the ladder for a ship.
- Scry `/x/domain/~comet` on `%gw-dns` (`GET /~/scry/gw-dns/domain/~comet.json`
  over Eyre) returns the assigned domain as a JSON string, whether pending or
  complete. `/x/requested` and `/x/completed` return the maps as nouns.

### Getting a URL for your comet (the runbook)

This is the whole procedure for a comet booted by `boot.sh` on its own
droplet. Four steps, two of them on the droplet's shell as root and two in
the ship's dojo. It takes about three minutes end to end.

1. **Forward port 80 to the ship, once, on the droplet.** `boot.sh` runs the
   ship on port 8080; the certificate authority validates on port 80. This
   rule sends 80 to 8080 and survives reboots (renewals need it too):

   ```sh
   iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
   DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent && netfilter-persistent save
   ```

   Check from anywhere outside the droplet: `curl http://<droplet ip>/~/host`
   prints the ship's name.

2. **Install this desk from the sponsor**, in the dojo (the sponsor publishes
   it; the local desk is named `%dns`):

   ```
   |install ~barmul-bolmet-ronlus-lighul--rovtun-satryc-moclug-daplyd %dns
   ```

   Wait for `kiln: merge into %dns succeeded` (a minute or two).

3. **Ask for the domain**, in the dojo, with the droplet's public IPv4:

   ```
   -dns!dns-address [%if .1.2.3.4]
   ```

   Within seconds it prints `dns: installed <name>.groundwire.me` and returns
   the turf. The name is two words of the ship's mnemonym (more if two are
   taken); the sponsor's `/x/domain/~comet` scry answers the same name.

4. **Wait for the certificate.** Eyre has handed the domain to `%acme`, which
   orders a certificate over port 80; the ship's log prints
   `http: web interface live on https://localhost:443` when it is installed,
   usually within two minutes. Verify: `curl https://<name>.groundwire.me/~/host`.

**What changes afterwards.** Once the certificate is live, eyre redirects
every plain-http request to https, so `http://<ip>:8080/...` now answers
`301 https://<ip>/...`, which fails TLS (the certificate is for the name).
From then on use `https://<name>.groundwire.me` everywhere: Landscape
(`/apps/landscape/`), Drive (`/drive`), Tlon (`/apps/groups/`), and the
address typed into any phone app. Sessions already logged in by IP must log
in again by name; the `+code` is unchanged.

**If it goes wrong.** The thread fails fast with a reason (`%ship-type-fail`
for a non-comet, `%reserved-address` for a private IP). A certificate that
never arrives means port 80 does not reach the ship from the internet: redo
step 1's check. The thread can be run again at any time; a new address for
the same ship replaces the old record.

### The mechanism

The comet needs nothing from this desk, and the user should never have to do
this step by hand: Causeway (or whatever drives the comet's VPS during
onboarding) reads the domain from the sponsor's `/x/domain/~comet` scry and
installs it on the comet's dojo:

```
|pass [%e %rule %turf %put /me/groundwire/kazoo/bespoke]
```

The turf is TLD first. Eyre then orders a certificate through `%acme`, and
the user is told the domain the first time they log in. Note that `%acme`
answers the HTTP-01 challenge on port 80, so a pier started with
`--http-port 8080` needs port 80 forwarded to it before the certificate can
be issued.

A comet with this desk can do the whole job itself:

```
-dns!dns-address [%if .1.2.3.4]
```

The thread watches `/~comet` on the sponsor's `%gw-dns`, pokes it with the
address, waits for the binding, and installs the turf. It produces the turf.
The sponsor's `@p` is a constant in `ted/dns/address.hoon`.

The thread does not check that port 80 reaches the ship, neither at the
address nor at the domain: `%acme` makes that check itself when it orders
the certificate, and retries on a timer if it fails. (The upstream thread
did both checks by fetching itself through iris, which hangs forever on a
ship whose eyre redirects unknown paths to `/~/login`, as every ship running
Landscape does: iris follows the redirect with the relative `location`
header and the runtime drops a request it cannot parse without answering.)

## State epochs

The agent's state is tagged with the date of the wordlist and zone it was
assigned under, `%~.2026.09.15` today, rather than `%0`. A new wordlist or a
new zone means a new tag and a new case in `+on-load` that reassigns every
domain, records the old one in `retired`, and re-requests every binding so
the sidecar writes the new records. Epochs step one at a time.

## Building

Dependencies are pinned in `build.zig` and fetched into `zig-out/` rather
than vendored: the upstream `dns` types and marks and the base-dev libraries
from `../urbit`, and `mnemonyms` with its English wordlist from GitHub.

```
zig build                # assemble zig-out/
zig build -Ddesk=<path>  # and replace the desk at <path> with it
zig build clean          # remove zig-out/
zig build clear          # also drop the cached dependency imports
zig test build.zig
```

`scripts/deploy.sh [host] [desk-path]` builds and rsyncs `zig-out/` into a
mounted desk on a remote pier. Then `|commit %dns` and, the first time,
`|install our %dns`.

Tests: `-test /=dns=/tests/lib/gw-dns` from the dojo, or `mcp/run-tests`.

## Sidecar

```
cd sidecar
GOOS=linux GOARCH=amd64 go build -o gw-dns-linux .
scp gw-dns-linux gw-comet-vps:/root/gw-dns
```

Configuration is by environment:

| variable      | default                 | meaning                          |
|---------------|-------------------------|----------------------------------|
| `URBIT_URL`   | `http://localhost:80` | the sponsor ship's Eyre          |
| `URBIT_SHIP`  |                         | the sponsor's `@p`               |
| `URBIT_CODE`  |                         | the sponsor's `+code`            |
| `DNS_ZONE`    | `groundwire.me`         | zone the domains hang under      |
| `DNS_BACKEND` | `log`                   | `log` prints, `do` writes to DigitalOcean DNS |
| `DO_TOKEN`    |                         | DigitalOcean token with DNS write scope, for `do` |

Run it in a screen session on the sponsor's VPS:

```
screen -dmS gw-dns sh -c 'set -a; . /root/.gw-dns.env; set +a; exec /root/gw-dns 2>&1 | tee -a /root/gw-dns.log'
```

The zone must live in DigitalOcean DNS for the `do` backend: create
`groundwire.me` there and point the registrar's nameservers at
`ns1.digitalocean.com`, `ns2.digitalocean.com` and `ns3.digitalocean.com`.
