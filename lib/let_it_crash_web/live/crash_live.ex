defmodule LetItCrashWeb.CrashLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.{Attendees, Crashes, Talks}

  @tick_ms 15_000
  @restart_overlay_ms 4_000

  @impl true
  def mount(_params, _session, socket) do
    room = socket.assigns.current_attendee.room

    if connected?(socket) do
      Crashes.subscribe_leaderboard()
      if room, do: Crashes.subscribe(room)
      Process.send_after(self(), :tick, @tick_ms)
    end

    {:ok,
     socket
     |> assign(:page_title, "Crash Meter")
     |> assign(:rooms, Talks.rooms())
     |> assign(:restarting, nil)
     |> assign(:leaderboard, Crashes.speaker_leaderboard())
     |> assign_room(room)}
  end

  defp assign_room(socket, room) do
    socket
    |> assign(:room, room)
    |> assign(:room_form, to_form(%{"room" => room}, as: :room))
    |> assign(:talk, room && Talks.current_talk(room))
    |> assign(:count, Crashes.meter(room))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Live Crash Meter
        <:subtitle>Did the live demo just crash? Tell everyone. Loudly.</:subtitle>
      </.header>

      <.form for={@room_form} id="room-form" phx-change="select_room">
        <.input
          field={@room_form[:room]}
          type="select"
          label="Room"
          prompt="Pick a room"
          options={@rooms}
        />
      </.form>

      <div id="current-talk" class="card bg-base-200 border border-base-300">
        <div class="card-body">
          <%= cond do %>
            <% @talk -> %>
              <p class="text-xs uppercase tracking-widest text-base-content/60">Now in {@room}</p>
              <h2 class="card-title">{@talk.title}</h2>
              <p class="text-base-content/70">{@talk.speaker}</p>
            <% @room -> %>
              <p>No talk running — crashes go to the hallway</p>
            <% true -> %>
              <p class="text-base-content/70">Pick a room to see what's (not) crashing.</p>
          <% end %>
        </div>
      </div>

      <button
        id="crash-btn"
        type="button"
        phx-click="crash"
        class="btn btn-error btn-lg w-full h-24 text-2xl font-black shadow-lg active:scale-95 transition"
      >
        💥 THE DEMO CRASHED
      </button>

      <div id="meter" class="space-y-1">
        <progress class="progress progress-error w-full h-4" max={Crashes.meter_max()} value={@count}></progress>
        <p class="text-sm font-mono">{@count} crashes in the last 2 min</p>
      </div>

      <section>
        <h2 class="font-bold">Most crashed speakers</h2>
        <p class="text-sm text-base-content/60 mb-2">
          Top of this list gets swag. Crashing is a feature.
        </p>
        <ol id="crash-leaderboard" class="list-decimal list-inside space-y-1">
          <li :for={row <- @leaderboard}>
            <span class="font-semibold">{row.speaker}</span>
            <span class="text-base-content/70">— {row.title}</span>
            <span class="badge badge-error badge-sm ml-1">{row.count}</span>
          </li>
        </ol>
        <p :if={@leaderboard == []} class="text-base-content/60 text-sm">
          No crashes yet. Suspicious.
        </p>
      </section>

      <div
        :if={@restarting}
        id="restart-overlay"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/90 text-error p-8"
      >
        <pre class="font-mono text-xl sm:text-3xl whitespace-pre-wrap text-center animate-pulse">{restart_text(@restarting)}</pre>
      </div>
    </Layouts.app>
    """
  end

  defp restart_text(:hallway), do: restart_text("the hallway")
  defp restart_text(%Talks.Talk{title: title}), do: restart_text(title)

  defp restart_text(title) when is_binary(title) do
    "** (EXIT) demo crashed\nSupervisor restarting #{title}… 3… 2… 1…"
  end

  @impl true
  def handle_event("select_room", %{"room" => %{"room" => room}}, socket) do
    room = if room == "", do: nil, else: room
    old_room = socket.assigns.room

    {:ok, attendee} = Attendees.set_room(socket.assigns.current_attendee, room)

    if old_room, do: Crashes.unsubscribe(old_room)
    if room, do: Crashes.subscribe(room)

    {:noreply,
     socket
     |> assign(:current_attendee, attendee)
     |> assign_room(room)}
  end

  def handle_event("crash", _params, socket) do
    case Crashes.report(socket.assigns.current_attendee, socket.assigns.room) do
      {:ok, %{count: count}} ->
        {:noreply, assign(socket, :count, count)}

      {:error, {:cooldown, s}} ->
        {:noreply,
         put_flash(socket, :error, "Backoff: your process is rate-limited for #{s}s more.")}

      {:error, :no_room} ->
        {:noreply, put_flash(socket, :error, "Pick a room first. Crashes need an address.")}
    end
  end

  @impl true
  def handle_info({:crash_meter, room, count}, %{assigns: %{room: room}} = socket) do
    {:noreply, assign(socket, :count, count)}
  end

  def handle_info({:supervisor_restart, room, talk}, %{assigns: %{room: room}} = socket) do
    Process.send_after(self(), :clear_restart, @restart_overlay_ms)
    {:noreply, assign(socket, :restarting, talk || :hallway)}
  end

  # Messages for a room we just switched away from.
  def handle_info({:crash_meter, _room, _count}, socket), do: {:noreply, socket}
  def handle_info({:supervisor_restart, _room, _talk}, socket), do: {:noreply, socket}

  def handle_info(:clear_restart, socket), do: {:noreply, assign(socket, :restarting, nil)}

  def handle_info(:tick, socket) do
    Process.send_after(self(), :tick, @tick_ms)
    room = socket.assigns.room

    {:noreply,
     socket
     |> assign(:count, Crashes.meter(room))
     |> assign(:talk, room && Talks.current_talk(room))}
  end

  def handle_info(:crash_leaderboard_changed, socket) do
    {:noreply, assign(socket, :leaderboard, Crashes.speaker_leaderboard())}
  end
end
