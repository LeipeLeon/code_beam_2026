defmodule LetItCrashWeb.ExcuseLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Excuses

  @tabs [{"excuse", "Excuse to skip a talk"}, {"wisdom", "Hallway wisdom"}]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Excuses",
       tabs: @tabs,
       kind: nil,
       seed: nil,
       text: nil,
       permalink: nil
     )}
  end

  @impl true
  def handle_params(%{"kind" => kind, "seed" => seed}, uri, socket)
      when kind in ["excuse", "wisdom"] do
    case Integer.parse(seed) do
      {seed, ""} when seed > 0 ->
        {:noreply,
         assign(socket,
           kind: kind,
           seed: seed,
           text: Excuses.generate(String.to_existing_atom(kind), seed),
           permalink: LetItCrashWeb.RequestURL.build(uri, ~p"/excuses/#{kind}/#{seed}")
         )}

      _ ->
        {:noreply, push_patch(socket, to: random_path(kind))}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: random_path("excuse"))}
  end

  defp random_path(kind), do: ~p"/excuses/#{kind}/#{Excuses.random_seed()}"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Excuse &amp; Hallway Wisdom Generator
        <:subtitle>Deterministic, shareable, and 100% pattern-matched.</:subtitle>
      </.header>

      <div role="tablist" class="tabs tabs-box">
        <.link
          :for={{kind, label} <- @tabs}
          id={"tab-#{kind}"}
          role="tab"
          patch={random_path(kind)}
          class={["tab", @kind == kind && "tab-active"]}
        >
          {label}
        </.link>
      </div>

      <blockquote
        :if={@text}
        id="excuse-text"
        class="border-l-4 border-primary pl-6 py-4 text-2xl sm:text-3xl font-semibold leading-snug"
      >
        {@text}
      </blockquote>

      <div :if={@kind} class="flex flex-wrap items-center gap-2">
        <.button id="another-btn" patch={random_path(@kind)} variant="primary">Another one</.button>
        <.button id="copy-btn" phx-click={JS.dispatch("phx:copy", to: "#permalink")}>
          Copy link
        </.button>
        <input
          id="permalink"
          type="text"
          readonly
          value={@permalink}
          class="input input-sm flex-1 min-w-48 font-mono"
        />
      </div>
    </Layouts.app>
    """
  end
end
