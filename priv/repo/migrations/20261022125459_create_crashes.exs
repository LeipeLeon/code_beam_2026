defmodule LetItCrash.Repo.Migrations.CreateCrashes do
  use Ecto.Migration

  def change do
    create table(:crashes) do
      add :attendee_id, references(:attendees, on_delete: :delete_all), null: false
      add :talk_id, references(:talks, on_delete: :nilify_all)
      add :room, :string, null: false

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:crashes, [:room, :inserted_at])
    create index(:crashes, [:attendee_id, :inserted_at])
    create index(:crashes, [:talk_id])
  end
end
