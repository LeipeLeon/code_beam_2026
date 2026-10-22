defmodule LetItCrashWeb.BingoLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Bingo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Bingo.subscribe_leaderboard()

    {:ok,
     socket
     |> assign(:page_title, "Bingo")
     |> assign(:card, Bingo.active_card(socket.assigns.current_attendee))
     |> assign(:bingo?, false)
     |> assign(:leaderboard, Bingo.leaderboard())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Let It Crash Bingo
        <:subtitle>
          Mark a square whenever a speaker says it. Honour system. We trust you (we don't).
        </:subtitle>
      </.header>

      <div id="bingo-card" class="grid grid-cols-5 gap-1.5 sm:gap-2">
        <button
          :for={{square, i} <- Enum.with_index(@card.squares)}
          id={"square-#{i}"}
          type="button"
          phx-click="toggle"
          phx-value-index={i}
          disabled={not is_nil(@card.completed_at)}
          class={[
            "aspect-square rounded-box border p-1 text-[0.65rem] sm:text-sm leading-tight font-medium",
            "flex items-center justify-center text-center transition active:scale-95",
            if(i in @card.marked,
              do: "bg-primary text-primary-content border-primary",
              else: "bg-base-100 border-base-300 hover:border-primary"
            ),
            i == Bingo.free_index() && "font-black"
          ]}
        >
          {square}
        </button>
      </div>

      <div :if={@card.completed_at && !@bingo?} class="text-center">
        <.button id="new-card-btn" phx-click="new_card" variant="primary">
          spawn a new card
        </.button>
      </div>

      <section>
        <h2 class="font-bold mb-2">Top bingo shouters</h2>
        <ol id="bingo-leaderboard" class="list-decimal list-inside space-y-1">
          <li :for={{attendee, count} <- @leaderboard}>
            <.attendee_label attendee={attendee} />
            <span class="text-base-content/60 text-sm">— {count} bingo(s)</span>
          </li>
        </ol>
        <p :if={@leaderboard == []} class="text-base-content/60 text-sm">
          Nobody has shouted BINGO yet. Listen harder.
        </p>
      </section>

      <div :if={@bingo?} id="bingo-modal" class="modal modal-open" role="dialog">
        <div class="modal-box text-center space-y-4">
          <h3 class="text-3xl font-black">BINGO! 🎉</h3>
          <p>Your card process exited :normal.</p>
          <div class="modal-action justify-center">
            <.button id="modal-new-card-btn" phx-click="new_card" variant="primary">
              spawn a new card
            </.button>
            <.button id="modal-close-btn" phx-click="close_modal">admire my card</.button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("toggle", %{"index" => index}, socket) do
    index = with {i, ""} <- Integer.parse(index), do: i, else: (_ -> nil)

    case Bingo.toggle(socket.assigns.card, index) do
      {:ok, card} -> {:noreply, assign(socket, :card, card)}
      {:bingo, card} -> {:noreply, assign(socket, card: card, bingo?: true)}
      {:error, :completed} -> {:noreply, put_flash(socket, :error, "This card already exited.")}
      {:error, :invalid} -> {:noreply, socket}
    end
  end

  def handle_event("new_card", _params, socket) do
    attendee = socket.assigns.current_attendee

    card =
      case Bingo.new_card(attendee) do
        {:ok, card} -> card
        {:error, :already_active} -> Bingo.active_card(attendee)
      end

    {:noreply, assign(socket, card: card, bingo?: false)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :bingo?, false)}
  end

  @impl true
  def handle_info(:bingo_leaderboard_changed, socket) do
    {:noreply, assign(socket, :leaderboard, Bingo.leaderboard())}
  end
end
