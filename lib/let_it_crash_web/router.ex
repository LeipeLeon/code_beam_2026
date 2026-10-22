defmodule LetItCrashWeb.Router do
  use LetItCrashWeb, :router

  import LetItCrashWeb.AttendeeAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LetItCrashWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_attendee
  end

  pipeline :admin_auth do
    plug :admin_basic_auth
  end

  scope "/", LetItCrashWeb do
    pipe_through :browser

    get "/join", JoinController, :new
    post "/join", JoinController, :create
  end

  scope "/", LetItCrashWeb do
    pipe_through [:browser, :require_attendee]

    get "/link/:id", LinkController, :create
  end

  scope "/", LetItCrashWeb do
    pipe_through :browser

    live_session :attendee, on_mount: [{LetItCrashWeb.AttendeeAuth, :require_attendee}] do
      live "/", HomeLive
      live "/bingo", BingoLive
      live "/tree", TreeLive
      live "/crash", CrashLive
      live "/excuses", ExcuseLive
      live "/excuses/:kind/:seed", ExcuseLive
    end
  end

  scope "/admin", LetItCrashWeb.Admin, as: :admin do
    pipe_through [:browser, :admin_auth]

    live_session :admin, on_mount: [{LetItCrashWeb.AdminAuth, :require_admin}] do
      live "/talks", TalkLive.Index, :index
      live "/talks/new", TalkLive.Form, :new
      live "/talks/:id", TalkLive.Show, :show
      live "/talks/:id/edit", TalkLive.Form, :edit
    end
  end

  defp admin_basic_auth(conn, _opts) do
    conn = Plug.BasicAuth.basic_auth(conn, Application.fetch_env!(:let_it_crash, :admin_auth))
    if conn.halted, do: conn, else: put_session(conn, :admin, true)
  end
end
