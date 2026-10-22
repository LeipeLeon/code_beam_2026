defmodule LetItCrash.Talks.Talk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "talks" do
    field :title, :string
    field :speaker, :string
    field :room, :string
    # Wall-clock time in the conference time zone (see :conference_time_zone).
    field :starts_at, :naive_datetime
    field :ends_at, :naive_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(talk, attrs) do
    talk
    |> cast(attrs, [:title, :speaker, :room, :starts_at, :ends_at])
    |> validate_required([:title, :speaker, :room, :starts_at, :ends_at])
    |> validate_ends_after_start()
  end

  defp validate_ends_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && NaiveDateTime.compare(ends_at, starts_at) != :gt do
      add_error(changeset, :ends_at, "must be after the start time")
    else
      changeset
    end
  end
end
