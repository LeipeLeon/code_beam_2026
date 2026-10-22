defmodule LetItCrash.Repo.Migrations.CreateTalks do
  use Ecto.Migration

  def change do
    create table(:talks) do
      add :title, :string, null: false
      add :speaker, :string, null: false
      add :room, :string, null: false
      add :starts_at, :naive_datetime, null: false
      add :ends_at, :naive_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:talks, [:room, :starts_at])
  end
end
