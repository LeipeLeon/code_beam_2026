defmodule LetItCrashWeb.AdminAuth do
  @moduledoc """
  LiveView websocket mounts skip router plugs, so the admin LiveViews check the
  session flag set by the router's basic-auth plug.
  """

  use LetItCrashWeb, :verified_routes

  def on_mount(:require_admin, _params, session, socket) do
    if session["admin"] == true do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end
end
