defmodule LetItCrashWeb.Admin.TalkLive.Show do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Talks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Talk {@talk.id}
        <:subtitle>This is a talk record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/talks"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/admin/talks/#{@talk}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit talk
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Title">{@talk.title}</:item>
        <:item title="Speaker">{@talk.speaker}</:item>
        <:item title="Room">{@talk.room}</:item>
        <:item title="Starts at">{@talk.starts_at}</:item>
        <:item title="Ends at">{@talk.ends_at}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Talk")
     |> assign(:talk, Talks.get_talk!(id))}
  end
end
