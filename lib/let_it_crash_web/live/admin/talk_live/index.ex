defmodule LetItCrashWeb.Admin.TalkLive.Index do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Talks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Talks
        <:actions>
          <.button variant="primary" navigate={~p"/admin/talks/new"}>
            <.icon name="hero-plus" /> New Talk
          </.button>
        </:actions>
      </.header>

      <.table
        id="talks"
        rows={@streams.talks}
        row_click={fn {_id, talk} -> JS.navigate(~p"/admin/talks/#{talk}") end}
      >
        <:col :let={{_id, talk}} label="Title">{talk.title}</:col>
        <:col :let={{_id, talk}} label="Speaker">{talk.speaker}</:col>
        <:col :let={{_id, talk}} label="Room">{talk.room}</:col>
        <:col :let={{_id, talk}} label="Starts at">{talk.starts_at}</:col>
        <:col :let={{_id, talk}} label="Ends at">{talk.ends_at}</:col>
        <:action :let={{_id, talk}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/talks/#{talk}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/talks/#{talk}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, talk}}>
          <.link
            phx-click={JS.push("delete", value: %{id: talk.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Talks")
     |> stream(:talks, list_talks())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    talk = Talks.get_talk!(id)
    {:ok, _} = Talks.delete_talk(talk)

    {:noreply, stream_delete(socket, :talks, talk)}
  end

  defp list_talks() do
    Talks.list_talks()
  end
end
