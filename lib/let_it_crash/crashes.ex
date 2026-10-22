defmodule LetItCrash.Crashes do
  @moduledoc """
  The live crash meter: attendees report "the demo crashed" per room.
  Enough crashes in a short window trigger a (purely cosmetic) supervisor restart.
  """

  import Ecto.Query

  alias LetItCrash.{Events, Repo, Talks}
  alias LetItCrash.Attendees.Attendee
  alias LetItCrash.Crashes.Crash
  alias LetItCrash.Talks.Talk

  @cooldown_seconds 30
  @window_seconds 120
  @restart_threshold 5
  @meter_max 10

  def subscribe(room), do: Phoenix.PubSub.subscribe(LetItCrash.PubSub, topic(room))
  def unsubscribe(room), do: Phoenix.PubSub.unsubscribe(LetItCrash.PubSub, topic(room))

  def subscribe_leaderboard,
    do: Phoenix.PubSub.subscribe(LetItCrash.PubSub, "crash_leaderboard")

  defp topic(room), do: "crash:" <> room

  def meter_max, do: @meter_max

  @doc """
  Reports a crash by `attendee` in `room`.
  """
  def report(_attendee, room) when room in [nil, ""], do: {:error, :no_room}

  def report(%Attendee{} = attendee, room) when is_binary(room) do
    now = DateTime.utc_now(:second)

    case seconds_since_last_crash(attendee, now) do
      age when is_integer(age) and age < @cooldown_seconds ->
        {:error, {:cooldown, @cooldown_seconds - age}}

      _ ->
        talk = Talks.current_talk(room)

        Repo.insert!(%Crash{
          attendee_id: attendee.id,
          talk_id: talk && talk.id,
          room: room,
          inserted_at: now
        })

        count = meter(room)
        restarted? = count == @restart_threshold

        Phoenix.PubSub.broadcast(LetItCrash.PubSub, topic(room), {:crash_meter, room, count})

        if restarted? do
          Phoenix.PubSub.broadcast(
            LetItCrash.PubSub,
            topic(room),
            {:supervisor_restart, room, talk}
          )

          what = if talk, do: "\"#{talk.title}\"", else: "the hallway"

          Events.broadcast(
            "💥 #{room}: demo crashed #{@restart_threshold}x — supervisor restarting #{what}"
          )
        end

        Phoenix.PubSub.broadcast(
          LetItCrash.PubSub,
          "crash_leaderboard",
          :crash_leaderboard_changed
        )

        {:ok, %{count: count, restarted?: restarted?, talk: talk}}
    end
  end

  defp seconds_since_last_crash(attendee, now) do
    last =
      Repo.one(
        from c in Crash,
          where: c.attendee_id == ^attendee.id,
          select: max(c.inserted_at)
      )

    last && DateTime.diff(now, last, :second)
  end

  @doc "Number of crashes in `room` during the last #{@window_seconds} seconds."
  def meter(room) when room in [nil, ""], do: 0

  def meter(room) do
    since = DateTime.add(DateTime.utc_now(:second), -@window_seconds, :second)

    Repo.aggregate(
      from(c in Crash, where: c.room == ^room and c.inserted_at > ^since),
      :count
    )
  end

  @doc "Talks ranked by crash count: `[%{speaker, title, count}]`."
  def speaker_leaderboard(limit \\ 10) do
    Repo.all(
      from c in Crash,
        join: t in Talk,
        on: t.id == c.talk_id,
        group_by: t.id,
        order_by: [desc: count(c.id), asc: t.id],
        limit: ^limit,
        select: %{speaker: t.speaker, title: t.title, count: count(c.id)}
    )
  end
end
