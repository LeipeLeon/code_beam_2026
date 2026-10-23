defmodule LetItCrashWeb.ExcuseLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Excuses

  @tabs [{"excuse", "Excuse to skip a talk"}, {"wisdom", "Hallway wisdom"}]
  @kinds %{"excuse" => :excuse, "wisdom" => :wisdom}

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
      when is_map_key(@kinds, kind) do
    case Integer.parse(seed) do
      {seed, ""} when seed > 0 ->
        {:noreply,
         assign(socket,
           kind: kind,
           seed: seed,
           text: Excuses.generate(Map.fetch!(@kinds, kind), seed),
           permalink: LetItCrashWeb.RequestURL.build(uri, ~p"/excuses/#{kind}/#{seed}")
         )}

      _ ->
        {:noreply, push_patch(socket, to: random_path(kind))}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: random_path("excuse"))}
  end

  # The seed must be picked when the user asks for a new one: a random path computed in
  # render/1 is only re-evaluated when its assigns change, so it would go stale.
  @impl true
  def handle_event("another", %{"kind" => kind}, socket) when is_map_key(@kinds, kind) do
    seed = fresh_seed(Map.fetch!(@kinds, kind), socket.assigns.text)
    {:noreply, push_patch(socket, to: ~p"/excuses/#{kind}/#{seed}")}
  end

  # Different seeds can produce the same text; re-roll so "Another one" visibly changes.
  defp fresh_seed(kind, current_text) do
    seed = Excuses.random_seed()

    if Excuses.generate(kind, seed) == current_text,
      do: fresh_seed(kind, current_text),
      else: seed
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
        <button
          :for={{kind, label} <- @tabs}
          id={"tab-#{kind}"}
          type="button"
          role="tab"
          aria-selected={to_string(@kind == kind)}
          phx-click="another"
          phx-value-kind={kind}
          class={["tab", @kind == kind && "tab-active"]}
        >
          {label}
        </button>
      </div>

      <blockquote
        :if={@text}
        id="excuse-text"
        class="border-l-4 border-primary pl-6 py-4 text-2xl sm:text-3xl font-semibold leading-snug"
      >
        {@text}
      </blockquote>

      <div :if={@kind} class="flex flex-wrap items-center gap-2">
        <.button id="another-btn" phx-click="another" phx-value-kind={@kind} variant="primary">
          Another one
        </.button>
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
