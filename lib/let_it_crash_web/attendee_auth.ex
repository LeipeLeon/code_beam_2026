defmodule LetItCrashWeb.AttendeeAuth do
  @moduledoc """
  Session-token identity for attendees: a plug for controllers and an
  `on_mount` hook for LiveViews.
  """

  use LetItCrashWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias LetItCrash.Attendees

  @doc "Assigns `:current_attendee` (or nil) from the session token."
  def fetch_current_attendee(conn, _opts) do
    assign(conn, :current_attendee, Attendees.get_by_token(get_session(conn, :attendee_token)))
  end

  @doc "Redirects to /join (remembering where to come back to) when not logged in."
  def require_attendee(conn, _opts) do
    if conn.assigns[:current_attendee] do
      conn
    else
      conn
      |> put_session(:return_to, current_path(conn))
      |> redirect(to: ~p"/join")
      |> halt()
    end
  end

  def on_mount(:require_attendee, _params, session, socket) do
    case Attendees.get_by_token(session["attendee_token"]) do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/join")}

      attendee ->
        {:cont, Phoenix.Component.assign(socket, :current_attendee, attendee)}
    end
  end
end
