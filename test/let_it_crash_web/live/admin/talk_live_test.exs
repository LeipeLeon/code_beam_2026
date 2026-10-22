defmodule LetItCrashWeb.Admin.TalkLiveTest do
  use LetItCrashWeb.ConnCase

  import Phoenix.LiveViewTest
  import LetItCrash.TalksFixtures

  @create_attrs %{
    title: "some title",
    speaker: "some speaker",
    room: "some room",
    starts_at: "2026-10-21T12:54:00",
    ends_at: "2026-10-21T13:54:00"
  }
  @update_attrs %{
    title: "some updated title",
    speaker: "some updated speaker",
    room: "some updated room",
    starts_at: "2026-10-22T12:54:00",
    ends_at: "2026-10-22T13:54:00"
  }
  @invalid_attrs %{title: nil, speaker: nil, room: nil, starts_at: nil, ends_at: nil}

  setup %{conn: conn} do
    %{
      conn:
        put_req_header(
          conn,
          "authorization",
          Plug.BasicAuth.encode_basic_auth("admin", "letitcrash")
        )
    }
  end

  defp create_talk(_) do
    talk = talk_fixture()

    %{talk: talk}
  end

  describe "Index" do
    setup [:create_talk]

    test "lists all talks", %{conn: conn, talk: talk} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/talks")

      assert html =~ "Listing Talks"
      assert html =~ talk.title
    end

    test "saves new talk", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/talks")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Talk")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/talks/new")

      assert render(form_live) =~ "New Talk"

      assert form_live
             |> form("#talk-form", talk: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#talk-form", talk: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/talks")

      html = render(index_live)
      assert html =~ "Talk created successfully"
      assert html =~ "some title"
    end

    test "updates talk in listing", %{conn: conn, talk: talk} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/talks")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#talks-#{talk.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/talks/#{talk}/edit")

      assert render(form_live) =~ "Edit Talk"

      assert form_live
             |> form("#talk-form", talk: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#talk-form", talk: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/talks")

      html = render(index_live)
      assert html =~ "Talk updated successfully"
      assert html =~ "some updated title"
    end

    test "deletes talk in listing", %{conn: conn, talk: talk} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/talks")

      assert index_live |> element("#talks-#{talk.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#talks-#{talk.id}")
    end
  end

  describe "Show" do
    setup [:create_talk]

    test "displays talk", %{conn: conn, talk: talk} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/talks/#{talk}")

      assert html =~ "Show Talk"
      assert html =~ talk.title
    end

    test "updates talk and returns to show", %{conn: conn, talk: talk} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/talks/#{talk}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/admin/talks/#{talk}/edit?return_to=show")

      assert render(form_live) =~ "Edit Talk"

      assert form_live
             |> form("#talk-form", talk: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#talk-form", talk: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/talks/#{talk}")

      html = render(show_live)
      assert html =~ "Talk updated successfully"
      assert html =~ "some updated title"
    end
  end
end
