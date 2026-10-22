defmodule LetItCrash.Tree.Link do
  use Ecto.Schema

  # Undirected link between two attendees; always stored with a_id < b_id.
  schema "links" do
    belongs_to :a, LetItCrash.Attendees.Attendee
    belongs_to :b, LetItCrash.Attendees.Attendee

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
