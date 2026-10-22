defmodule LetItCrash.Repo.Migrations.CreateBingoCards do
  use Ecto.Migration

  def change do
    create table(:bingo_cards) do
      add :attendee_id, references(:attendees, on_delete: :delete_all), null: false
      add :squares, {:array, :string}, null: false
      add :marked, {:array, :integer}, null: false, default: [12]
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bingo_cards, [:attendee_id],
             where: "completed_at IS NULL",
             name: :bingo_cards_one_active_index
           )

    create index(:bingo_cards, [:attendee_id, :completed_at])
  end
end
