defmodule LetItCrashWeb.TreeLive do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Tree

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Tree.subscribe()

    {:ok,
     socket
     |> assign(:page_title, "Supervisor Tree")
     |> assign(:link_form, to_form(%{"id" => ""}, as: :link))
     |> load_tree()}
  end

  defp load_tree(socket) do
    socket
    |> assign(:forest, Tree.forest())
    |> assign(:top_linked, Tree.top_linked())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Supervisor Tree of Attendees
        <:subtitle>Scan a badge to link. Your first link becomes your supervisor.</:subtitle>
      </.header>

      <div id="tree" class="card bg-base-200 border border-base-300 overflow-x-auto">
        <div class="card-body font-mono text-sm">
          <p class="font-bold">LetItCrash.Application (strategy: :one_for_one)</p>
          <ul class="ml-3 border-l border-base-content/20 pl-4 space-y-1">
            <.tree_node :for={node <- @forest} node={node} me={@current_attendee.id} />
          </ul>
        </div>
      </div>

      <.form for={@link_form} id="link-form" phx-submit="link" class="flex items-end gap-2">
        <div class="flex-1">
          <.input field={@link_form[:id]} type="number" label="Link by PID <0.N.0>" min="1" />
        </div>
        <.button variant="primary" class="btn btn-primary mb-2">Link</.button>
      </.form>

      <section>
        <h2 class="font-bold mb-2">Most linked processes</h2>
        <ol id="top-linked" class="list-decimal list-inside space-y-1">
          <li :for={{attendee, count} <- @top_linked}>
            <.attendee_label attendee={attendee} />
            <span class="text-base-content/60 text-sm">— {count} links</span>
          </li>
        </ol>
        <p :if={@top_linked == []} class="text-base-content/60 text-sm">
          Nobody has linked yet. Go network.
        </p>
      </section>
    </Layouts.app>
    """
  end

  attr :node, :map, required: true
  attr :me, :integer, required: true

  defp tree_node(assigns) do
    ~H"""
    <li id={"node-#{@node.attendee.id}"}>
      <span class={[
        "inline-flex flex-wrap items-baseline gap-1 rounded px-1",
        @node.attendee.id == @me && "bg-primary/15 ring-1 ring-primary",
        @node.attendee.exited_at && "opacity-50 line-through"
      ]}>
        <.attendee_label attendee={@node.attendee} />
        <span :if={@node.link_count > 0} class="text-base-content/60">
          ({@node.link_count} links)
        </span>
        <span :if={@node.attendee.exited_at}> — exited :normal</span>
      </span>
      <ul :if={@node.children != []} class="ml-3 border-l border-base-content/20 pl-4 mt-1 space-y-1">
        <.tree_node :for={child <- @node.children} node={child} me={@me} />
      </ul>
    </li>
    """
  end

  @impl true
  def handle_event("link", %{"link" => %{"id" => id}}, socket) do
    case Integer.parse(id) do
      {id, ""} when id > 0 -> {:noreply, redirect(socket, to: ~p"/link/#{id}")}
      _ -> {:noreply, put_flash(socket, :error, "badarg")}
    end
  end

  @impl true
  def handle_info(:tree_changed, socket), do: {:noreply, load_tree(socket)}
end
