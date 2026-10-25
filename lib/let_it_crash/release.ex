defmodule LetItCrash.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :let_it_crash

  @doc """
  Creates the database if needed, migrates and runs the (idempotent) seeds.
  Used by the `app` service in compose.yaml before starting the server.
  """
  def setup do
    load_app()

    for repo <- repos() do
      case repo.__adapter__().storage_up(repo.config()) do
        :ok -> :ok
        {:error, :already_up} -> :ok
        {:error, reason} -> raise "could not create database: #{inspect(reason)}"
      end
    end

    migrate()
    seed()
  end

  @doc "Runs priv/repo/seeds.exs; safe to re-run."
  def seed do
    # Seeds broadcast PubSub events and read the time zone database, so start the whole app
    # (the endpoint doesn't serve requests here, as PHX_SERVER isn't set).
    {:ok, _} = Application.ensure_all_started(@app)
    Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))
    :ok
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
