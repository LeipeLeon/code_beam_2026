defmodule LetItCrash.Repo.Migrations.CreateAttendees do
  use Ecto.Migration

  def change do
    create table(:attendees) do
      add :nickname, :string, null: false
      add :token_hash, :binary, null: false
      add :supervisor_id, references(:attendees, on_delete: :nilify_all)
      add :room, :string
      add :exited_at, :utc_datetime
      add :exit_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:attendees, ["lower(nickname)"], name: :attendees_nickname_lower_index)
    create unique_index(:attendees, [:token_hash])
    create index(:attendees, [:supervisor_id])
  end
end
