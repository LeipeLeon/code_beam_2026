defmodule LetItCrashWeb.JoinController do
  use LetItCrashWeb, :controller

  alias LetItCrash.Attendees

  plug :redirect_if_joined

  def new(conn, _params) do
    render(conn, :new, form: Phoenix.Component.to_form(Attendees.change_registration()))
  end

  def create(conn, %{"attendee" => %{"nickname" => nickname}}) do
    case Attendees.register(nickname) do
      {:ok, attendee, raw_token} ->
        return_to = get_session(conn, :return_to) || ~p"/"

        conn
        |> configure_session(renew: true)
        |> delete_session(:return_to)
        |> put_session(:attendee_token, raw_token)
        |> put_flash(
          :info,
          "Spawned as #{Attendees.pid_label(attendee)}. Try not to crash. Or do."
        )
        |> redirect(to: return_to)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(changeset, action: :insert))
    end
  end

  def create(conn, _params), do: create(conn, %{"attendee" => %{"nickname" => ""}})

  defp redirect_if_joined(conn, _opts) do
    if conn.assigns[:current_attendee] do
      conn |> redirect(to: ~p"/") |> halt()
    else
      conn
    end
  end
end
