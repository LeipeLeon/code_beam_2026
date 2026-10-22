defmodule LetItCrash.Crashes.Crash do
  use Ecto.Schema

  schema "crashes" do
    field :room, :string

    belongs_to :attendee, LetItCrash.Attendees.Attendee
    belongs_to :talk, LetItCrash.Talks.Talk

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
