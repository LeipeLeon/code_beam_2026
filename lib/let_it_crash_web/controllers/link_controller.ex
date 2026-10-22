defmodule LetItCrashWeb.LinkController do
  use LetItCrashWeb, :controller

  alias LetItCrash.{Attendees, Tree}

  # A GET on purpose: phone cameras open badge QR codes as plain URLs.
  def create(conn, %{"id" => id}) do
    conn
    |> link_flash(Integer.parse(id), conn.assigns.current_attendee)
    |> redirect(to: ~p"/tree")
  end

  defp link_flash(conn, {id, ""}, me) do
    case Tree.link(me, id) do
      {:ok, :supervised} ->
        other = Attendees.get!(id)

        put_flash(
          conn,
          :info,
          "Linked! #{Attendees.pid_label(other)} #{other.nickname} is now your supervisor. Behave."
        )

      {:ok, :linked} ->
        put_flash(
          conn,
          :info,
          "Linked with #{Attendees.pid_label(Attendees.get!(id))}. You already have a supervisor, so this is just friendship."
        )

      {:ok, :already_linked} ->
        put_flash(conn, :info, "Already linked. {:error, :eexist}")

      {:error, :self} ->
        put_flash(
          conn,
          :error,
          "You can't link to yourself. That's a deadlock waiting to happen."
        )

      {:error, :not_found} ->
        put_flash(conn, :error, "No such process. Maybe it was never spawned.")

      {:error, :exited} ->
        put_flash(conn, :error, "That process has exited :normal. Let it rest.")
    end
  end

  defp link_flash(conn, _invalid, _me), do: put_flash(conn, :error, "badarg: that's not a PID")
end
