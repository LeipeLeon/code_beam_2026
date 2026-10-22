defmodule LetItCrash.Repo.Migrations.CreateLinks do
  use Ecto.Migration

  def change do
    create table(:links) do
      add :a_id, references(:attendees, on_delete: :delete_all), null: false
      add :b_id, references(:attendees, on_delete: :delete_all), null: false

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create unique_index(:links, [:a_id, :b_id])
    create index(:links, [:b_id])
    create constraint(:links, :links_ordered_pair, check: "a_id < b_id")
  end
end
