defmodule LetItCrash.Attendees.Attendee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attendees" do
    field :nickname, :string
    field :token_hash, :binary, redact: true
    field :room, :string
    field :exited_at, :utc_datetime
    field :exit_reason, :string

    belongs_to :supervisor, __MODULE__

    timestamps(type: :utc_datetime)
  end

  @doc false
  def registration_changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:nickname])
    |> update_change(:nickname, &String.trim/1)
    |> validate_required([:nickname])
    |> validate_length(:nickname, min: 2, max: 24)
    |> validate_format(:nickname, ~r/^[\p{L}\p{N} _.\-]+$/u,
      message: "only letters, digits, spaces, _ . and -"
    )
    |> unique_constraint(:nickname,
      name: :attendees_nickname_lower_index,
      message: "already spawned — pick another name"
    )
  end
end
