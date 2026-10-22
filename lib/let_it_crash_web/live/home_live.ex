defmodule LetItCrashWeb.HomeLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.{Events, Tree}

  @features [
    {"Let It Crash Bingo", "/bingo",
     "Mark clichés as speakers say them. Five in a row exits your card :normal."},
    {"Supervisor Tree", "/tree", "Scan badges, get linked, get supervised. Cycles not included."},
    {"Live Crash Meter", "/crash",
     "Did the demo crash? Report it. Five crashes restart the talk."},
    {"Excuse Generator", "/excuses",
     "Excuses to skip a talk and hallway wisdom, with permalinks."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Events.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:features, @features)
     |> stream(:events, [], at: 0, limit: 20)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="card bg-base-200 border border-base-300">
        <div class="card-body sm:flex-row sm:items-center gap-6">
          <div class="flex-1 space-y-3">
            <p class="text-xs uppercase tracking-widest text-base-content/60">self()</p>
            <h1 class={[
              "text-3xl font-black",
              @current_attendee.exited_at && "opacity-50 line-through"
            ]}>
              <.attendee_label attendee={@current_attendee} />
            </h1>
            <%= if @current_attendee.exited_at do %>
              <p class="text-sm text-base-content/70">
                You exited :normal. Your children were adopted. Feeling better?
              </p>
              <.button id="restart-btn" phx-click="restart" variant="primary">Restart</.button>
            <% else %>
              <.button
                id="exit-btn"
                phx-click="exit"
                class="btn btn-outline btn-error font-mono"
                data-confirm="Really exit? Your children get re-parented to your supervisor."
              >
                exit(self(), :normal)
              </.button>
            <% end %>
          </div>
          <figure class="flex flex-col items-center gap-2 text-center">
            <div id="badge-qr" class="w-56 bg-white p-2 rounded-box [&>svg]:w-full [&>svg]:h-auto">
              {raw(@qr_svg)}
            </div>
            <figcaption class="text-xs text-base-content/70 max-w-56">
              Others scan this to link with you. First link = they become your supervisor.
            </figcaption>
          </figure>
        </div>
      </section>

      <section class="grid sm:grid-cols-2 gap-4">
        <.link
          :for={{title, path, blurb} <- @features}
          navigate={path}
          class="card bg-base-100 border border-base-300 hover:border-primary hover:-translate-y-0.5 transition"
        >
          <div class="card-body">
            <h2 class="card-title">{title}</h2>
            <p class="text-sm text-base-content/70">{blurb}</p>
          </div>
        </.link>
      </section>

      <section class="space-y-2">
        <h2 class="font-mono text-sm uppercase tracking-widest text-base-content/60">
          :sys.trace(:conference)
        </h2>
        <ul id="events" phx-update="stream" class="font-mono text-sm space-y-1">
          <li class="hidden only:block text-base-content/50">Waiting for messages…</li>
          <li :for={{id, event} <- @streams.events} id={id} class="flex gap-3">
            <time class="text-base-content/50 shrink-0">{local_time(event.at)}</time>
            <span>{event.text}</span>
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("exit", _params, socket) do
    {:ok, attendee} = Tree.exit(socket.assigns.current_attendee)
    {:noreply, assign(socket, :current_attendee, attendee)}
  end

  def handle_event("restart", _params, socket) do
    {:ok, attendee} = Tree.restart(socket.assigns.current_attendee)
    {:noreply, assign(socket, :current_attendee, attendee)}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :qr_svg, badge_qr(uri, socket.assigns.current_attendee))}
  end

  @impl true
  def handle_info({:event, event}, socket) do
    {:noreply, stream_insert(socket, :events, event, at: 0, limit: 20)}
  end

  defp badge_qr(uri, attendee) do
    LetItCrashWeb.RequestURL.build(uri, ~p"/link/#{attendee.id}")
    |> EQRCode.encode()
    |> EQRCode.svg(width: 220)
  end

  defp local_time(at) do
    at
    |> DateTime.shift_zone!(Application.fetch_env!(:let_it_crash, :conference_time_zone))
    |> Calendar.strftime("%H:%M:%S")
  end
end
