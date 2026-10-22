defmodule LetItCrash.Attendees do
  @moduledoc """
  Nickname-only attendees. Each attendee is identified by a random session
  token; only its SHA-256 hash is stored. A lost cookie means a new nickname.
  """

  alias LetItCrash.{Events, Repo, Tree}
  alias LetItCrash.Attendees.Attendee

  @doc "The fake PID shown next to every nickname."
  def pid_label(%Attendee{id: id}), do: "<0.#{id}.0>"

  def change_registration(attrs \\ %{}) do
    Attendee.registration_changeset(%Attendee{}, attrs)
  end

  @doc """
  Registers a new attendee. Returns the raw token to store in the session.
  """
  def register(nickname) do
    raw_token = :crypto.strong_rand_bytes(32)

    %Attendee{token_hash: hash_token(raw_token)}
    |> Attendee.registration_changeset(%{nickname: nickname})
    |> Repo.insert()
    |> case do
      {:ok, attendee} ->
        Events.broadcast("#{pid_label(attendee)} #{attendee.nickname} spawned")
        Tree.broadcast_changed()
        {:ok, attendee, raw_token}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def get_by_token(raw_token) when is_binary(raw_token) do
    Repo.get_by(Attendee, token_hash: hash_token(raw_token))
  end

  def get_by_token(_), do: nil

  def get!(id), do: Repo.get!(Attendee, id)

  def set_room(%Attendee{} = attendee, room) do
    attendee
    |> Ecto.Changeset.change(room: room)
    |> Repo.update()
  end

  defp hash_token(raw_token), do: :crypto.hash(:sha256, raw_token)
end
