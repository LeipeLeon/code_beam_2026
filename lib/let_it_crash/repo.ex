defmodule LetItCrash.Repo do
  use Ecto.Repo,
    otp_app: :let_it_crash,
    adapter: Ecto.Adapters.Postgres
end
