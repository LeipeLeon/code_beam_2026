defmodule LetItCrash.Bingo.Card do
  use Ecto.Schema

  schema "bingo_cards" do
    field :squares, {:array, :string}
    field :marked, {:array, :integer}, default: [12]
    field :completed_at, :utc_datetime

    belongs_to :attendee, LetItCrash.Attendees.Attendee

    timestamps(type: :utc_datetime)
  end
end
