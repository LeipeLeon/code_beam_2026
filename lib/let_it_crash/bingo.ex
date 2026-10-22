defmodule LetItCrash.Bingo do
  @moduledoc """
  Let It Crash Bingo: a 5×5 card of conference clichés with a free square in
  the middle. Completing a line "exits" the card process.
  """

  import Ecto.Query

  alias LetItCrash.{Attendees, Events, Repo}
  alias LetItCrash.Attendees.Attendee
  alias LetItCrash.Bingo.Card

  @free_index 12
  @free_square "Let it crash"

  @phrases [
    "Hot code reloading",
    "Nine nines",
    "WhatsApp",
    "It's just a GenServer",
    "Supervision tree",
    "Ericsson",
    "Telecom switches",
    "Joe Armstrong quote",
    "Pattern matching!",
    "The actor model",
    "Backpressure",
    "Distributed Erlang is easy",
    "Netsplit",
    "Mnesia (nervous laughter)",
    "Dialyzer complained",
    "Gleam mention",
    "Rust NIF",
    "LiveView replaced our SPA",
    "Pipe operator",
    "Process mailbox overflow",
    "Observer screenshot",
    "OTP 29",
    "Typed Elixir",
    "Set-theoretic types",
    "Nerves on a Raspberry Pi",
    "Elixir is fast enough",
    "It depends",
    "Speaker drinks water mid-sentence",
    "Live demo fails",
    "\"Can you see my screen?\"",
    "Hand raise survey",
    "\"Any questions?\" → silence",
    "BEAM VM diagram",
    "Immutable data",
    "Fault tolerance",
    "Soft real-time",
    "Shared-nothing",
    "Reductions",
    "Scheduler per core",
    "Kubernetes (booing)",
    "\"We're hiring\"",
    "Laptop out of battery",
    "Microphone feedback",
    "Slide with 200 lines of code",
    "Mix release",
    "Ecto query"
  ]

  @lines for(r <- 0..4, do: Enum.map(0..4, &(r * 5 + &1))) ++
           for(c <- 0..4, do: Enum.map(0..4, &(&1 * 5 + c))) ++
           [Enum.map(0..4, &(&1 * 6)), Enum.map(0..4, &(&1 * 4 + 4))]

  def subscribe_leaderboard,
    do: Phoenix.PubSub.subscribe(LetItCrash.PubSub, "bingo_leaderboard")

  def free_index, do: @free_index

  @doc "The attendee's active card, creating one if needed."
  def active_card(%Attendee{} = attendee) do
    get_active(attendee) || insert_card!(attendee)
  end

  @doc "Spawns a fresh card; only allowed when there is no active card."
  def new_card(%Attendee{} = attendee) do
    case get_active(attendee) do
      nil -> {:ok, insert_card!(attendee)}
      %Card{} -> {:error, :already_active}
    end
  end

  defp get_active(attendee) do
    Repo.one(from c in Card, where: c.attendee_id == ^attendee.id and is_nil(c.completed_at))
  end

  defp insert_card!(attendee) do
    squares = @phrases |> Enum.take_random(24) |> List.insert_at(@free_index, @free_square)

    Repo.insert!(
      %Card{attendee_id: attendee.id, squares: squares, marked: [@free_index]},
      on_conflict: :nothing,
      conflict_target: {:unsafe_fragment, "(attendee_id) WHERE completed_at IS NULL"}
    )
    |> case do
      %Card{id: nil} -> get_active(attendee)
      card -> card
    end
  end

  @doc """
  Toggles square `index` on `card`. Returns `{:bingo, card}` when this
  completed a line.
  """
  def toggle(%Card{completed_at: %DateTime{}}, _index), do: {:error, :completed}

  def toggle(%Card{}, index) when not is_integer(index) or index not in 0..24,
    do: {:error, :invalid}

  def toggle(%Card{} = card, @free_index), do: {:ok, card}

  def toggle(%Card{} = card, index) do
    marked =
      if index in card.marked,
        do: List.delete(card.marked, index),
        else: Enum.sort([index | card.marked])

    if bingo?(marked) do
      card =
        card
        |> Ecto.Changeset.change(marked: marked, completed_at: DateTime.utc_now(:second))
        |> Repo.update!()

      attendee = Attendees.get!(card.attendee_id)

      Events.broadcast(
        "🎉 #{Attendees.pid_label(attendee)} #{attendee.nickname} shouted BINGO " <>
          "(card process exited :normal)"
      )

      Phoenix.PubSub.broadcast(
        LetItCrash.PubSub,
        "bingo_leaderboard",
        :bingo_leaderboard_changed
      )

      {:bingo, card}
    else
      {:ok, card |> Ecto.Changeset.change(marked: marked) |> Repo.update!()}
    end
  end

  @doc "True when `marked` covers a full row, column or diagonal."
  def bingo?(marked) do
    Enum.any?(@lines, fn line -> Enum.all?(line, &(&1 in marked)) end)
  end

  @doc "Attendees ranked by completed cards: `[{attendee, count}]`."
  def leaderboard(limit \\ 10) do
    Repo.all(
      from c in Card,
        join: a in assoc(c, :attendee),
        where: not is_nil(c.completed_at),
        group_by: a.id,
        order_by: [desc: count(c.id), asc: min(c.completed_at)],
        limit: ^limit,
        select: {a, count(c.id)}
    )
  end
end
