# Let It Crash — Code BEAM companion

![beam me up!](./assets/Gemini_Generated_Image_lts1dylts1dylts1.jpg)

Bingo, a supervisor tree of attendees, an excuse generator and a live crash meter.

Design and implementation plan: [`docs/plan.md`](docs/plan.md).

> **Vibecoded** with omp and cmux: an AI coding agent wrote the code from a short prompt, a few
> multiple-choice questions and a stream of follow-up requests. See [How this was built](#how-this-was-built).

## Features

### Join and home

Pick a nickname and you're spawned as a process with a fake PID. Home shows your badge QR code (others
scan it to link with you), links to every feature and a live `:sys.trace` ticker of what's happening
at the conference.

<img src="docs/screenshots/join.webp" width="49%" alt="Join page: spawn/3 yourself"> <img src="docs/screenshots/home.webp" width="49%" alt="Home page with badge QR code and live ticker">

### Let It Crash Bingo

A 5×5 card of conference clichés with "Let it crash" as the free square. A full row, column or
diagonal exits your card process `:normal` and puts you on the leaderboard.

<img src="docs/screenshots/bingo.webp" width="49%" alt="Bingo card with marked squares and leaderboard"> <img src="docs/screenshots/bingo-modal.webp" width="49%" alt="BINGO modal">

### Supervisor Tree of Attendees

Scanning someone's badge links you. Your first link makes them your supervisor, unless that would
create a cycle. When someone exits, their children are restarted under their supervisor.

<img src="docs/screenshots/tree.webp" width="70%" alt="Supervisor tree with nested attendees and most-linked list">

### Live Crash Meter

Pick your room and press the button when the live demo crashes. Five crashes within two minutes
trigger a supervisor restart of the talk on every screen in that room. The most crashed speakers get
a leaderboard.

<img src="docs/screenshots/crash-meter.webp" width="49%" alt="Crash meter for the Main Stage talk"> <img src="docs/screenshots/crash-restart.webp" width="49%" alt="Supervisor restart overlay">

### Excuse and hallway wisdom generator

Deterministic excuses to skip a talk, plus hallway wisdom. Every result has a shareable permalink.

<img src="docs/screenshots/excuses.webp" width="70%" alt="Excuse generator with permalink">

### Admin

Password-protected talk schedule management at `/admin/talks`.

<img src="docs/screenshots/admin-talks.webp" width="70%" alt="Admin talk listing">

## Running locally

* `docker compose up -d db` starts Postgres 18 on host port 5433
* `mkcert -install && mkdir -p priv/cert && mkcert -cert-file priv/cert/localhost.pem -key-file priv/cert/localhost-key.pem localhost 127.0.0.1 ::1`
  creates the locally-trusted certificate dev serves HTTPS with (once per machine; `priv/cert/` is gitignored)
* `mix setup` installs deps, creates/migrates the DB and seeds placeholder talks
* `mix phx.server`, then visit [`https://localhost:4000`](https://localhost:4000)
* `mix tunnel` (in a second terminal) exposes the dev server through a Cloudflare quick tunnel and
  prints a random `https://….trycloudflare.com` URL. Badge QR codes and permalinks use whichever
  host the visitor came in on.

Admin: [`/admin/talks`](https://localhost:4000/admin/talks) (basic auth, dev: `admin` / `letitcrash`;
prod: `ADMIN_USER` / `ADMIN_PASSWORD`). Talk times are wall-clock times in the conference time zone
(`:conference_time_zone`, default `Europe/Berlin`).

### Everything in Docker

To run the app itself in a container (production release, plain HTTP), no Elixir needed:

```sh
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" > .env   # once; .env is gitignored
docker compose up -d --build
```

Then open [`http://localhost:4001`](http://localhost:4001). On start the container creates the
`let_it_crash_prod` database, migrates and seeds it (safe to repeat). Admin credentials default to
`admin` / `letitcrash`; set `ADMIN_USER` / `ADMIN_PASSWORD` in `.env` to change them.

#### Advertise on the LAN

To let phones and laptops on the same Wi-Fi open the container app at `http://foo.local:4001`:

```sh
docker compose up -d --build
bin/advertise   # keep it running; Ctrl-C withdraws the names
```

`bin/advertise` registers each name in `MDNS_NAMES` (space-separated, default `foo.local bar.local`)
with the macOS mDNS responder, pointing at `HOST_IP` (default: the address of `en0`) and port 4001.
The app reads the same `MDNS_NAMES`, so set it in `.env` to change both. It's a host-side script
because an mDNS sidecar in Docker doesn't work on macOS: with OrbStack, Avahi on the VM's host
network was only answered on the Mac's VM bridge (`bridge100`), never on `en0`.

- `HOST_IP` is fixed at start; re-run `bin/advertise` after switching networks.
- Venue Wi-Fi with client isolation, or networks that filter multicast, block mDNS. Use `mix tunnel`
  there instead.
- The app redirects to HTTPS for every host except localhost and the names in `MDNS_NAMES`, which is
  why those names are served over plain HTTP.

## How this was built

This project was vibecoded with [omp](https://github.com/can1357/oh-my-pi) (a coding agent) running inside
[cmux](https://github.com/manaflow-ai/cmux) (a macOS terminal built for AI coding agents; its built-in browser
was used for the end-to-end checks and the screenshots above). The agent planned, wrote, ran and
verified the code; a human picked options and steered.

### Original prompt

> we want a quirky companion app for a conference. it must be funny! do you have any suggestions?

The project directory was called `code_beam`, so the agent assumed the conference was
[Code BEAM](https://codebeameurope.com/) (Erlang/Elixir) and leaned the jokes on BEAM concepts.

### Questions the agent asked

Chosen answers are in **bold**.

1. **Which funny features should the companion app have?** (pick any)
   - **Let It Crash Bingo**: talk bingo card with BEAM clichés ("hot code reload", "9 nines", "WhatsApp", "it's just a GenServer"). Shout BINGO → live leaderboard.
   - **Supervisor Tree of Attendees**: each attendee is a "process"; you "link" by scanning badges. Live visual tree. Leaving early = "process exited :normal".
   - Mailbox Messaging: send anonymous messages to any attendee's "mailbox". Messages may arrive out of order on purpose; unread count shown as "mailbox overflow" warnings.
   - **Excuse / Hallway Generator**: generates fake-profound BEAM wisdom and excuses to skip a talk ("my supervisor restarted me").
   - **Live Crash Meter**: attendees press "crash" when a live demo fails; global meter + "restart strategy" animations. Swag for the most crashed speaker.
2. **What should it be built with?**
   - **Phoenix LiveView**: Elixir, fits the conference, real-time features (bingo, crash meter) come almost free via PubSub. Mobile-web, no app store.
   - Phoenix API + mobile app: native feel, but app-store review timeline and much more work.
   - Static web app: cheapest hosting; no real-time/multi-user features.
3. **Persistence / identity?**
   - **Postgres + nickname login**: pick a nickname, magic cookie session; no passwords. Standard Phoenix setup.
   - In-memory only (ETS): zero infra, state lost on restart — on-brand "let it crash", but leaderboards reset.
   - Postgres + email magic link: real identities, needs email delivery setup.
4. **To award "most crashed speaker" and rank bingo per talk, the app needs the talk schedule. How should talks get in?**
   - **Seed file + admin page**: talks (title, speaker, room, start/end) in `priv/repo/seeds.exs` plus a password-protected `/admin` page to add/edit. Crash presses attach to the talk currently running in your selected room.
   - No talks at all: crash meter is global only, no speaker leaderboard. Simplest.
   - Import from a schedule URL/JSON: needs the actual schedule feed format; you'd have to provide it.
5. **Deployment target for this plan?**
   - **Local dev only for now**: plan ends with a working app on localhost + Postgres in Docker; deploy later.
   - Fly.io: adds fly launch config, Fly Postgres, release setup.
   - Docker image (any host): adds a Phoenix release Dockerfile; you host it.

From those answers the agent wrote [`docs/plan.md`](docs/plan.md). After it was approved, the build
session implemented it. Follow-up requests in that session added HTTPS, a public tunnel, these
screenshots and a more inclusive demo cast, and fixed bugs found along the way.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
