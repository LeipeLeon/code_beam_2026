# Let It Crash — Code BEAM companion app

## Context

Build a funny companion web app for Code BEAM, the Erlang/Elixir conference, in the empty directory `/Users/berl/Clients/projects/code_beam`. It has four features: **Let It Crash Bingo**, **Supervisor Tree of Attendees**, **Excuse / Hallway Wisdom Generator** and a **Live Crash Meter** with a "most crashed speaker" leaderboard. Stack: Phoenix LiveView, Postgres, nickname-only login. Talks come from a seed file plus a password-protected admin page. Target for now: working on localhost only (no deploy config).

Environment facts (checked): Elixir 1.19.5 / OTP 29 via mise; Docker is available; no `psql` on the host; no `phx_new` archive installed; latest `phx_new` is 1.8.16. Existing Docker Postgres containers do not publish 5432 to the host, but this app still uses host port **5433** so it can't collide with them.

## Approach

### 1. Scaffold the project and dev database

1. `mix archive.install hex phx_new 1.8.16 --force`
2. In `/Users/berl/Clients/projects/code_beam`: `mix phx.new . --app let_it_crash --module LetItCrash --no-mailer --no-dashboard`. Answer `Y` to fetch deps. Keep the default bigint ids, because PIDs are built from them.
3. Create `compose.yaml` in the project root:
   ```yaml
   services:
     db:
       image: postgres:18
       environment:
         POSTGRES_USER: postgres
         POSTGRES_PASSWORD: postgres
       ports: ["5433:5432"]
       volumes: ["pgdata:/var/lib/postgresql"]
   volumes:
     pgdata:
   ```
   (postgres 18 images expect the volume at `/var/lib/postgresql`, not `/var/lib/postgresql/data`.)
4. In `config/dev.exs` and `config/test.exs`, add `port: 5433` to the `LetItCrash.Repo` config.
5. In `mix.exs` deps, add `{:eqrcode, "~> 0.2.1"}` and `{:tzdata, "~> 1.2"}`.
6. In `config/config.exs`, add:
   ```elixir
   config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
   config :let_it_crash, :conference_time_zone, "Europe/Berlin"
   config :let_it_crash, :admin_auth, username: "admin", password: "letitcrash"
   ```
   In `config/runtime.exs` inside the `if config_env() == :prod` block, read the credentials from `System.fetch_env!("ADMIN_USER")` / `System.fetch_env!("ADMIN_PASSWORD")` into the same key.
7. In `lib/let_it_crash_web/endpoint.ex`, add `max_age: 60 * 60 * 24 * 30` to `@session_options` so the nickname session lasts the whole conference.
8. Follow the generated `AGENTS.md` and Phoenix 1.8 conventions: `<Layouts.app flash={@flash}>` wrapper, `<.input>`/`<.form>` core components, streams for lists, Tailwind v4 + daisyUI classes. (Assumption: phx_new 1.8.16 generates `AGENTS.md`. If it doesn't, follow the patterns in the generated `core_components.ex` and `layouts.ex`.)

Done when `docker compose up -d && mix setup && mix test` passes on the bare scaffold.

### 2. Data model and migrations

Create these migrations and schemas. Contexts are listed in step 3.

**`attendees`** (`LetItCrash.Attendees.Attendee`)
- `nickname :string, null: false`. Changeset: trim, length 2..24, format `~r/^[\p{L}\p{N} _.\-]+$/u`. Unique index on `lower(nickname)` named `attendees_nickname_lower_index`; changeset `unique_constraint(:nickname, name: :attendees_nickname_lower_index, message: "already spawned — pick another name")`.
- `token_hash :binary, null: false`, unique index.
- `supervisor_id references(:attendees, on_delete: :nilify_all)`, indexed.
- `room :string` (the room selected on the crash meter; nullable).
- `exited_at :utc_datetime` (nullable) and `exit_reason :string` (nullable).
- `timestamps(type: :utc_datetime)`.
- Function `LetItCrash.Attendees.pid_label(%Attendee{id: id})` → `"<0.#{id}.0>"`. Every UI spot that shows an attendee shows `pid_label` followed by the nickname.

**`links`** (`LetItCrash.Tree.Link`): `a_id`, `b_id` (both `references(:attendees, on_delete: :delete_all)`, not null), `inserted_at` only (`timestamps(updated_at: false, type: :utc_datetime)`). Always store `a_id < b_id`. Unique index on `[:a_id, :b_id]`. Check constraint `a_id < b_id`.

**`talks`** (`LetItCrash.Talks.Talk`): `title`, `speaker`, `room` (strings, not null), `starts_at`, `ends_at` (`:naive_datetime`, not null; **wall-clock time in the conference time zone**, so the generated admin `datetime-local` inputs work unchanged). Changeset validates `ends_at > starts_at`. Index on `[:room, :starts_at]`.

**`crashes`** (`LetItCrash.Crashes.Crash`): `attendee_id` (`on_delete: :delete_all`, not null), `talk_id` (`on_delete: :nilify_all`, nullable), `room :string, null: false`, `inserted_at` only (utc_datetime). Indexes: `[:room, :inserted_at]`, `[:attendee_id, :inserted_at]`, `[:talk_id]`.

**`bingo_cards`** (`LetItCrash.Bingo.Card`): `attendee_id` (`on_delete: :delete_all`, not null), `squares {:array, :string}` (25 entries), `marked {:array, :integer}` (default `[12]`), `completed_at :utc_datetime` (nullable), timestamps. Partial unique index `[:attendee_id]` `where: "completed_at IS NULL"` named `bingo_cards_one_active_index` (one active card per attendee).

Generate the talks admin with the generator (step 6) rather than writing the talks migration by hand. The other tables get hand-written migrations.

### 3. Contexts (pure business logic, all PubSub broadcasting lives here)

PubSub server: the generated `LetItCrash.PubSub`. Topics and messages (exact tuples):
- `"events"`: `{:event, %{id: System.unique_integer([:positive]), text: String.t(), at: DateTime.t()}}` — global ticker.
- `"tree"`: `:tree_changed`.
- `"crash:" <> room`: `{:crash_meter, room, count}` and `{:supervisor_restart, room, talk_or_nil}`.
- `"crash_leaderboard"`: `:crash_leaderboard_changed`.
- `"bingo_leaderboard"`: `:bingo_leaderboard_changed`.

Add a helper module `LetItCrash.Events` with `subscribe/0` and `broadcast(text)`. It builds the event map above. All contexts call `Events.broadcast/1` for ticker lines.

**`LetItCrash.Attendees`**
- `register(nickname) :: {:ok, attendee, raw_token} | {:error, changeset}`. Raw token = `:crypto.strong_rand_bytes(32)`, stored as `:crypto.hash(:sha256, raw)`. On success it broadcasts the event `"#{pid} #{nick} spawned"` and `:tree_changed`.
- `get_by_token(raw_token) :: attendee | nil`.
- `get!(id)`, `set_room(attendee, room)`.
- If someone loses their cookie, they pick a new nickname. There is no recovery flow on purpose.

**`LetItCrash.Tree`**
- `link(%Attendee{} = me, other_id) :: {:ok, :supervised | :linked | :already_linked} | {:error, :self | :not_found | :exited}`.
  - `other_id == me.id` → `{:error, :self}`. Unknown id → `:not_found`. Either side has `exited_at` set → `:exited`.
  - Upsert the `links` row (`on_conflict: :nothing`). If no row was inserted and supervisor stays unchanged → `:already_linked`.
  - If `me.supervisor_id` is nil **and** `me` is not an ancestor of `other`, set `me.supervisor_id = other.id` → `:supervised`. Find out whether `me` is an ancestor by walking `other`'s `supervisor_id` chain in Elixir (one `Repo.get` per hop, stop at nil). Otherwise → `:linked`.
  - Run everything in one `Repo.transaction`. On success, broadcast `:tree_changed` and an event: `"#{me_pid} is now supervised by #{other_pid}"` or `"#{a_pid} ⇄ #{b_pid} linked"`.
- `exit(attendee) :: {:ok, attendee}`. In one transaction: set `exited_at = now`, `exit_reason = "normal"`, and `supervisor_id = nil`. Then re-parent all direct children to the exiting attendee's former supervisor (`update_all`). Event: `"#{pid} #{nick} exited :normal — #{n} children restarted under #{new_parent_pid or "the application"}"`. Broadcast `:tree_changed`.
- `restart(attendee)`: clears `exited_at`/`exit_reason`. Event `"#{pid} restarted (it's fine, that's the point)"`. Broadcast `:tree_changed`.
- `forest() :: [node]` where `node = %{attendee: a, children: [node], link_count: integer}`. Load all attendees plus link counts (one grouped query over both `a_id` and `b_id`) and build the tree in memory. Roots are attendees with nil `supervisor_id`. Sort children by id. Exited attendees stay in as leaves.
- `top_linked(limit \\ 10)` → `[{attendee, count}]`.

**`LetItCrash.Talks`** (generated by `phx.gen.live`, plus):
- `conference_now() :: NaiveDateTime.t()` = `DateTime.now!(Application.fetch_env!(:let_it_crash, :conference_time_zone)) |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)`.
- `current_talk(room, now \\ conference_now())` → the talk with `starts_at <= now and ends_at > now`, ordered by `starts_at desc`, `limit 1`. `ends_at` is exclusive.
- `rooms()` → distinct `room` values, sorted.

**`LetItCrash.Crashes`**
- Module attributes: `@cooldown_seconds 30`, `@window_seconds 120`, `@restart_threshold 5`, `@meter_max 10`.
- `report(attendee, room) :: {:ok, %{count: n, restarted?: boolean, talk: talk | nil}} | {:error, {:cooldown, seconds_left}} | {:error, :no_room}`.
  - Nil or empty room → `:no_room`.
  - If the attendee's latest crash is younger than 30 s → `{:cooldown, 30 - age}`.
  - Insert a crash with `talk_id` from `Talks.current_talk(room)`, then count crashes in `room` over the last 120 s.
  - Broadcast `{:crash_meter, room, count}`. If `count == @restart_threshold` exactly, also broadcast `{:supervisor_restart, room, talk}` and the event `"💥 #{room}: demo crashed #{@restart_threshold}x — supervisor restarting \"#{talk.title}\""` (when there is no talk, `"... restarting the hallway"`). Comparing with `==` means one burst triggers only one restart.
  - Broadcast `:crash_leaderboard_changed`.
- `meter(room) :: integer`: count in the last 120 s.
- `meter_max/0` → 10.
- `speaker_leaderboard(limit \\ 10)` → `[%{speaker, title, count}]`: join crashes→talks, group by talk, order by count desc.

**`LetItCrash.Bingo`**
- `@free_square "Let it crash"` sits at index 12. `@phrases` holds the pool listed in step 8 (≥ 40 entries).
- `active_card(attendee)` → the existing active card, or a newly inserted one with `squares = Enum.take_random(@phrases, 24)` and the free square inserted at index 12, `marked: [12]`.
- `toggle(card, index) :: {:ok, card} | {:bingo, card} | {:error, :completed | :invalid}`. Index 12 can't be unmarked (no-op `{:ok, card}`). Indices outside 0..24 → `:invalid`. A completed card → `:completed`. After toggling, check `bingo?(marked)`. On bingo, set `completed_at`, broadcast the event `"🎉 #{pid} #{nick} shouted BINGO (card process exited :normal)"` and `:bingo_leaderboard_changed`, and return `{:bingo, card}`.
- `bingo?(marked) :: boolean` — public and pure. The 12 lines are the 5 rows, 5 columns and 2 diagonals over indices `row*5+col`.
- `new_card(attendee)` → only allowed when there is no active card. It inserts a new one.
- `leaderboard(limit \\ 10)` → `[{attendee, completed_count}]`.

**`LetItCrash.Excuses`** (pure, no DB)
- `generate(kind, seed) :: String.t()` with `kind in [:excuse, :wisdom]` and `seed` a positive integer. It's deterministic: `state = :rand.seed_s(:exsss, seed)`, then pick each template slot with `:rand.uniform_s/2`, threading the state. Never use the process-global `:rand`.
- `random_seed/0` → `:rand.uniform(1_000_000_000)`.
- The templates and slot pools are in step 8.

### 4. Identity: join, session, on_mount

- `LetItCrashWeb.AttendeeAuth`:
  - plug `fetch_current_attendee/2`: reads `get_session(conn, :attendee_token)`, then `Attendees.get_by_token`, then `assign(:current_attendee, a_or_nil)`.
  - `on_mount(:require_attendee, ...)`: reads the token from the session, assigns `:current_attendee`, and halts with `redirect(to: ~p"/join")` when it's missing.
  - plug `require_attendee/2` for controllers: when missing, stores `put_session(:return_to, current_path(conn))` and redirects to `/join`.
- `LetItCrashWeb.JoinController`:
  - `new` renders a form: heading "spawn/3 yourself", one `nickname` input, button "Spawn process".
  - `create` calls `Attendees.register`. On success it runs `configure_session(renew: true)`, `put_session(:attendee_token, raw)`, and redirects to `get_session(:return_to) || ~p"/"` (deleting `:return_to`) with flash `"Spawned as #{pid}. Try not to crash. Or do."`. On error it re-renders with the changeset errors.
  - Visiting `/join` while already logged in redirects to `/`.
- Add `plug :fetch_current_attendee` to the `:browser` pipeline.

### 5. LiveViews and routes

Router (`lib/let_it_crash_web/router.ex`), `:browser` scope:
```elixir
get "/join", JoinController, :new
post "/join", JoinController, :create

scope "/", LetItCrashWeb do
  pipe_through [:browser, :require_attendee]
  get "/link/:id", LinkController, :create
end

live_session :attendee, on_mount: [{LetItCrashWeb.AttendeeAuth, :require_attendee}] do
  live "/", HomeLive
  live "/bingo", BingoLive
  live "/tree", TreeLive
  live "/crash", CrashLive
  live "/excuses", ExcuseLive          # redirects (push_patch) to a random seed
  live "/excuses/:kind/:seed", ExcuseLive
end
```
Excuses need login too, so the ticker and nav stay consistent.

Add a nav bar to `Layouts.app` (links: Home, Bingo, Tree, Crash Meter, Excuses) and a footer line: `"Uptime: 99.9999999% (citation needed)"`.

**`HomeLive`** (`/`)
- Shows the current attendee's `pid_label` and nickname, with buttons "exit(self(), :normal)" (calls `Tree.exit`) or "Restart" when exited.
- **Badge QR**: `EQRCode.encode(url(~p"/link/#{@current_attendee.id}")) |> EQRCode.svg(width: 220)` rendered with `Phoenix.HTML.raw/1`. Caption: "Others scan this to link with you. First link = they become your supervisor."
- Four feature cards linking to the pages.
- **Live ticker**: subscribe to `"events"` when `connected?`. Use `stream(:events, [], at: 0, limit: 20)` and insert new events at 0.

**`LinkController.create`** (`GET /link/:id`; a GET because phone camera QR scans open URLs)
- Parse `id` with `Integer.parse`; invalid input → flash error `"badarg: that's not a PID"`.
- Call `Tree.link(conn.assigns.current_attendee, id)`. Flash per result:
  - `:supervised` → `"Linked! #{pid} #{nick} is now your supervisor. Behave."`
  - `:linked` → `"Linked with #{pid}. You already have a supervisor, so this is just friendship."`
  - `:already_linked` → `"Already linked. {:error, :eexist}"`
  - `:self` → `"You can't link to yourself. That's a deadlock waiting to happen."`
  - `:not_found` → `"No such process. Maybe it was never spawned."`
  - `:exited` → `"That process has exited :normal. Let it rest."`
- Always redirect to `~p"/tree"`.

**`TreeLive`** (`/tree`)
- Subscribes to `"tree"`. On `:tree_changed`, reloads `Tree.forest()` and `Tree.top_linked()`.
- Renders a root node `"LetItCrash.Application (strategy: :one_for_one)"` with the forest as nested `<ul>`, through a recursive function component `tree_node/1`.
  - Each node shows `pid_label nickname`, and `(#{link_count} links)` when > 0.
  - Exited nodes render with `opacity-50 line-through` and the suffix `" — exited :normal"`.
  - Highlight the current attendee's node.
- A "Link by PID" form with a numeric input `id`. Submit → `redirect(to: ~p"/link/#{id}")`. Non-integer input → flash `"badarg"`.
- A "Most linked processes" top-10 list.

**`BingoLive`** (`/bingo`)
- Mount loads `Bingo.active_card` and subscribes to `"bingo_leaderboard"`.
- 5×5 grid of buttons with `phx-click="toggle" phx-value-index={i}`. Marked squares are styled as filled.
- On `{:bingo, card}`, show a modal: "BINGO! 🎉 Your card process exited :normal." plus a button "spawn a new card" (`phx-click="new_card"` → `Bingo.new_card`).
- Leaderboard: "Top bingo shouters".
- Header subtitle: "Mark a square whenever a speaker says it. Honour system. We trust you (we don't)."

**`CrashLive`** (`/crash`)
- Room `<select>` from `Talks.rooms()`, preselected to `@current_attendee.room`. Changing it calls `Attendees.set_room`, unsubscribes the old `"crash:" <> room` topic and subscribes to the new one.
- Shows the current talk (`Talks.current_talk(room)`: title, speaker), or "No talk running — crashes go to the hallway".
- A big red daisyUI button: "💥 THE DEMO CRASHED".
  - `{:error, {:cooldown, s}}` → flash `"Backoff: your process is rate-limited for #{s}s more."`
  - `:no_room` → flash `"Pick a room first. Crashes need an address."`
- Meter: `<progress max={Crashes.meter_max()} value={@count}>` with the label `"#{@count} crashes in the last 2 min"`. Recompute the meter on mount and on every `{:crash_meter, room, count}`. Also refresh it every 15 s with `Process.send_after(self(), :tick, 15_000)` while connected, so old crashes fall out of the window.
- On `{:supervisor_restart, room, talk}`, set the assign `restarting: talk || :hallway`. That shows a full-screen overlay: `"** (EXIT) demo crashed\nSupervisor restarting #{title}… 3… 2… 1…"` with Tailwind `animate-pulse`. Clear it with `Process.send_after(self(), :clear_restart, 4_000)`.
- "Most crashed speakers" leaderboard subscribed to `"crash_leaderboard"`. Caption: "Top of this list gets swag. Crashing is a feature."

**`ExcuseLive`** (`/excuses`, `/excuses/:kind/:seed`)
- `handle_params`: with no params, `push_patch` to `~p"/excuses/excuse/#{Excuses.random_seed()}"`. An invalid kind or seed patches to a new random one.
- Two tabs: "Excuse to skip a talk" (`excuse`) and "Hallway wisdom" (`wisdom`).
- Shows the generated text in a big quote block.
- Buttons: "Another one" (push_patch to the same kind with a new seed) and "Copy link". "Copy link" uses `phx-click={JS.dispatch("phx:copy", to: "#permalink")}` plus a small listener in `assets/js/app.js`: `window.addEventListener("phx:copy", e => navigator.clipboard.writeText(e.target.value))`. `#permalink` is a readonly input holding `url(~p"/excuses/#{kind}/#{seed}")`.

### 6. Admin talks page

- Run `mix phx.gen.live Talks Talk talks title:string speaker:string room:string starts_at:naive_datetime ends_at:naive_datetime --web Admin`.
  - Add the `ends_at > starts_at` validation and the `[:room, :starts_at]` index to the generated changeset and migration.
  - If the generator asks about scopes, answer so that it generates **without** a scope (there's no `phx.gen.auth`).
- Router: add a pipeline `pipeline :admin_auth do plug :admin_basic_auth end`. Define `defp admin_basic_auth(conn, _opts)` in the router: `conn = Plug.BasicAuth.basic_auth(conn, Application.fetch_env!(:let_it_crash, :admin_auth))`, then `if conn.halted, do: conn, else: put_session(conn, :admin, true)`. Put the generated routes in `scope "/admin", LetItCrashWeb.Admin, as: :admin do pipe_through [:browser, :admin_auth]; live_session :admin, on_mount: [{LetItCrashWeb.AdminAuth, :require_admin}] do <generated live routes> end end`.
- New module `LetItCrashWeb.AdminAuth` with `on_mount(:require_admin, _params, session, socket)`: `{:cont, socket}` when `session["admin"] == true`, otherwise `{:halt, redirect(socket, to: ~p"/")}`. It's needed because the LiveView websocket mount doesn't go through router plugs.
- Admin talk times are entered in conference local time ("Europe/Berlin" wall clock). Add a hint line on the form: "Times are local conference time".

### 7. Seeds

`priv/repo/seeds.exs` must be safe to re-run: insert talks only if `Repo.aggregate(Talk, :count) == 0`, and attendees only if `Repo.aggregate(Attendee, :count) == 0`. Never delete data.
- Seed 6 placeholder talks on today's conference date. `start = Talks.conference_now()` truncated to the hour (minute and second set to 0). Slot 1 runs `start` → `start + 1h`; slot 2 runs `start + 1h` → `start + 2h`. That way the crash meter has a current talk during dev.
- Slot 1 (Main Stage, Room B, Room C, in that order):
  - "Hot Code Reloading My Marriage" — Ann Upgrade
  - "Nine Nines and Other Lies We Tell Management" — Dr. Ova Load
  - "It's Just a GenServer (It's Never Just a GenServer)" — Gen Serverson
- Slot 2 (Main Stage, Room B, Room C, in that order):
  - "Rewriting It in Rust: A Hostage Situation" — Ferris Crab
  - "Mailbox Zero: Selective Receive for Your Inbox" — Mona Box
  - "Live Demo Driven Development" — Murphy McLaw
- Attendees: create them with `Attendees.register("Robert the Supervisor")` and `Attendees.register("José-ish")`, throwing the tokens away. Then set José-ish's `supervisor_id` to Robert with `Ecto.Changeset.change/2 |> Repo.update!`, so `/tree` isn't empty.

The admin replaces these with the real schedule through `/admin/talks`.

### 8. Humor content (put verbatim in the modules)

**Bingo phrases** (`LetItCrash.Bingo` `@phrases`):
"Hot code reloading", "Nine nines", "WhatsApp", "It's just a GenServer", "Supervision tree", "Ericsson", "Telecom switches", "Joe Armstrong quote", "Pattern matching!", "The actor model", "Backpressure", "Distributed Erlang is easy", "Netsplit", "Mnesia (nervous laughter)", "Dialyzer complained", "Gleam mention", "Rust NIF", "LiveView replaced our SPA", "Pipe operator", "Process mailbox overflow", "Observer screenshot", "OTP 29", "Typed Elixir", "Set-theoretic types", "Nerves on a Raspberry Pi", "Elixir is fast enough", "It depends", "Speaker drinks water mid-sentence", "Live demo fails", "\"Can you see my screen?\"", "Hand raise survey", "\"Any questions?\" → silence", "BEAM VM diagram", "Immutable data", "Fault tolerance", "Soft real-time", "Shared-nothing", "Reductions", "Scheduler per core", "Kubernetes (booing)", "\"We're hiring\"", "Laptop out of battery", "Microphone feedback", "Slide with 200 lines of code", "Mix release", "Ecto query"

**Excuse template** (`kind: :excuse`): `"Sorry, can't make #{talk_slot} — #{reason_slot}, so #{consequence_slot}."`
- `talk_slot`: "this talk", "the keynote", "the 9am session", "the panel", "the lightning talks", "the workshop"
- `reason_slot`: "my supervisor restarted me", "my mailbox has 40,000 unread messages", "I'm stuck in a selective receive", "I hit a netsplit with the coffee machine", "my process was OOM-killed by the buffet", "I'm hot-code-reloading my personality", "Dialyzer says I'm not allowed", "I'm waiting on a GenServer.call with :infinity timeout", "I got linked to someone in the hallway and can't trap exits", "I've exceeded my reductions for today"
- `consequence_slot`: "I'll be back in 5 seconds (default restart intensity)", "please send the slides to my mailbox", "I'll watch it in the hallway track", "consider this an :ignore", "I'll pattern-match on the recording later", "my supervisor will explain", "let it crash"

**Wisdom template** (`kind: :wisdom`): `"#{opener_slot} #{truth_slot}. #{closer_slot}"`
- `opener_slot`: "As the Erlang docs probably say:", "Ancient Ericsson proverb:", "Overheard at the coffee queue:", "Senior BEAM engineer, after 3 espressos:", "A wise process once told me:"
- `truth_slot`: "a crash is just a restart you haven't scheduled yet", "every problem is a GenServer if you squint", "there is no shared state, only shared regret", "the real supervision tree was the friends we linked along the way", "if it compiles, the Dialyzer will find something", "nine nines is just eight nines with confidence", "your mailbox is a queue of other people's priorities", "pattern matching is just saying no politely", "distributed systems are easy until the second node"
- `closer_slot`: "Let it crash.", "{:ok, :enlightened}", "** (EXIT) normal", "Restart intensity: high.", "Send this to someone's mailbox.", ":ok"

## Critical files & anchors

- `lib/let_it_crash/tree.ex` — `link/2` ancestor walk and `exit/1` re-parenting. This is the only cycle-prone logic.
- `lib/let_it_crash/crashes.ex` — cooldown, 120 s window and the `== @restart_threshold` single-trigger rule.
- `lib/let_it_crash/bingo.ex` — `bingo?/1` line set and the free square at index 12.
- `lib/let_it_crash_web/attendee_auth.ex` — the session token plug plus on_mount. Every route depends on it.
- `lib/let_it_crash_web/router.ex` — admin basic-auth pipeline + `live_session :admin` on_mount, plus the GET `/link/:id` route behind `require_attendee` (so QR scans log in first and then come back via `:return_to`).

## Verification

Prerequisites: run from `/Users/berl/Clients/projects/code_beam`, Docker running, then `docker compose up -d && mix setup` (creates the DB, migrates, runs seeds).

**Automated tests** (`mix test`). Add focused context tests:
- `test/let_it_crash/bingo_test.exs`:
  - `bingo?([12])` → false.
  - Row `[10,11,12,13,14]` → true.
  - Column `[2,7,12,17,22]` → true.
  - Anti-diagonal `[4,8,12,16,20]` → true.
  - `[0,1,2,3,5]` → false (row wraparound must not count).
  - Toggling index 12 leaves it marked.
  - Toggling on a completed card → `{:error, :completed}`.
- `test/let_it_crash/tree_test.exs`:
  - A links to B → `:supervised`, and A's supervisor is B.
  - B then links to A → `:linked`, and B's supervisor stays nil (no cycle).
  - Repeating the link → `:already_linked`.
  - Linking to self → `{:error, :self}`.
  - C supervised by A, A supervised by B; `Tree.exit(A)` → C's supervisor becomes B and A is marked exited.
- `test/let_it_crash/crashes_test.exs`:
  - A second report within 30 s → `{:error, {:cooldown, _}}`.
  - Five different attendees reporting in the same room → only the 5th result has `restarted?: true`. A 6th attendee gets `restarted?: false`.
  - A subscriber to `"crash:Room B"` receives exactly one `{:supervisor_restart, "Room B", _}` (`assert_receive` + `refute_receive`).
- `test/let_it_crash/talks_test.exs`: a talk 10:00–11:00. `current_talk(room, ~N[2026-10-22 11:00:00])` → nil (end exclusive); at `10:59:59` → the talk.
- `test/let_it_crash/excuses_test.exs`: `generate(:excuse, 42) == generate(:excuse, 42)`, and the result starts with `"Sorry, can't make "`.

**Manual end-to-end** (`mix phx.server`, then http://localhost:4000):
1. In browser A, open `/` → redirected to `/join`. Spawn as "Alice" → home shows `<0.N.0> Alice`, a QR code, and the ticker line "<0.N.0> Alice spawned".
2. In browser B (private window), join as "Bob". The ticker in A shows Bob spawning live, without a reload.
3. In B, open `/link/<Alice's id>` → flash "…is now your supervisor. Behave." `/tree` in both browsers shows Bob nested under Alice, live.
4. In B, open `/crash` and select "Main Stage". In A, select "Main Stage" too and press the crash button: meter 1 for both. Press again in A → cooldown flash. Getting 5 presses needs 5 attendees; spawn 3 more private windows, or rely on the automated test. Then both see the restart overlay for ~4 s, and the speaker leaderboard lists the seeded Main Stage talk.
5. In A, open `/bingo` and mark a full row → BINGO modal. B's home ticker shows "🎉 … shouted BINGO". The leaderboard shows Alice with 1.
6. Open `/excuses` → redirected to `/excuses/excuse/<seed>`. Reloading the same URL shows the same text; "Another one" changes it.
7. In A, press "exit(self(), :normal)" → in `/tree`, Alice is greyed out and Bob is moved to the root.
8. Open `/admin/talks` → Basic-auth prompt. `admin` / `letitcrash` lets you in. Create a talk in "Room C" running now → `/crash` with "Room C" shows it as the current talk.

## Assumptions & contingencies

- The conference time zone is `Europe/Berlin` (config key `:conference_time_zone`). Change that one config value for another venue.
- Dev admin credentials are `admin` / `letitcrash` in `config/config.exs`. In prod they come from env vars.
- UI copy is English.
- If `mix phx.new .` refuses because the directory isn't empty (e.g. hidden files), answer `Y` to its "continue" prompt. Never delete existing files.
- If port 5433 is taken on the host, use 5434 in both `compose.yaml` and the dev/test repo configs.
- If `EQRCode.svg/2` doesn't accept `width:` in 0.2.1, call `EQRCode.svg/1` and constrain the size with a wrapping `div class="w-56"`.

## Changes after approval

- **No new tests.** The context tests listed under Verification were dropped on request; only the generated suite remains (fixtures adjusted for `ends_at > starts_at`, admin LiveView test sends basic auth). The manual end-to-end walkthrough was run instead.
- **HTTPS in dev.** Dev serves HTTPS on port 4000 with a locally-trusted `mkcert` certificate in `priv/cert/` (gitignored); plain `http://localhost:4000` no longer works. `config/runtime.exs` applies `PORT` to `https` in dev and `http` elsewhere.
- **Public tunnel.** `mix tunnel` (`bin/tunnel`) starts a Cloudflare quick tunnel to the dev server, verifying the origin against the mkcert CA.
- **Request-relative links.** Badge QR codes and excuse permalinks are built from the URL the visitor used (`LetItCrashWeb.RequestURL`), not the endpoint `url` config, so they work on localhost and through the tunnel.
- **Tree mutations are serialised** with a Postgres advisory lock so concurrent links can't form a cycle.
- **Ticker:** your own "spawned" line isn't shown to you (it's broadcast before your home page subscribes); times are shown in the conference time zone.
- **Small UI additions:** confirm prompt on `exit(self(), :normal)`, an "admire my card" button on the bingo modal, page title "Let It Crash"; the generated `PageController` was removed.
- **Seed attendees** are "Sofía the Supervisor" and "Wei the Worker" (instead of "Robert the Supervisor" / "José-ish"), for a more inclusive demo cast.
- **Compose runs the whole app.** `compose.yaml` has an `app` service built from the standard `mix phx.gen.release --docker` Dockerfile, on `http://localhost:4001`. On start it runs `LetItCrash.Release.setup` (create DB, migrate, idempotent seeds) and then the release. `SECRET_KEY_BASE` comes from a gitignored `.env`; dev only needs `docker compose up -d db`.
- **LAN names via mDNS.** `bin/advertise` registers the names with the macOS mDNS responder, announcing `MDNS_NAMES` (default `foo.local bar.local`) for port 4001. The prod endpoint skips the HTTPS redirect for those names (`LetItCrashWeb.LanHosts`) and adds them to `check_origin`. The OrbStack `dev.orbstack.domains` label on db was removed because it claimed the same names.
