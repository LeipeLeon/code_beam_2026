# Let It Crash — Code BEAM companion

Bingo, a supervisor tree of attendees, an excuse generator and a live crash meter.

Design and implementation plan: [`docs/plan.md`](docs/plan.md).

To start locally:

* `docker compose up -d` starts Postgres 18 on host port 5433
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

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
