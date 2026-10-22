defmodule LetItCrashWeb.Admin.TalkLive.Form do
  use LetItCrashWeb, :live_view

  alias LetItCrash.Talks
  alias LetItCrash.Talks.Talk

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage talk records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="talk-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:speaker]} type="text" label="Speaker" />
        <.input field={@form[:room]} type="text" label="Room" />
        <.input field={@form[:starts_at]} type="datetime-local" label="Starts at" />
        <.input field={@form[:ends_at]} type="datetime-local" label="Ends at" />
        <p class="text-sm text-base-content/60 mb-4">Times are local conference time</p>
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Talk</.button>
          <.button navigate={return_path(@return_to, @talk)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    talk = Talks.get_talk!(id)

    socket
    |> assign(:page_title, "Edit Talk")
    |> assign(:talk, talk)
    |> assign(:form, to_form(Talks.change_talk(talk)))
  end

  defp apply_action(socket, :new, _params) do
    talk = %Talk{}

    socket
    |> assign(:page_title, "New Talk")
    |> assign(:talk, talk)
    |> assign(:form, to_form(Talks.change_talk(talk)))
  end

  @impl true
  def handle_event("validate", %{"talk" => talk_params}, socket) do
    changeset = Talks.change_talk(socket.assigns.talk, talk_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"talk" => talk_params}, socket) do
    save_talk(socket, socket.assigns.live_action, talk_params)
  end

  defp save_talk(socket, :edit, talk_params) do
    case Talks.update_talk(socket.assigns.talk, talk_params) do
      {:ok, talk} ->
        {:noreply,
         socket
         |> put_flash(:info, "Talk updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, talk))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_talk(socket, :new, talk_params) do
    case Talks.create_talk(talk_params) do
      {:ok, talk} ->
        {:noreply,
         socket
         |> put_flash(:info, "Talk created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, talk))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _talk), do: ~p"/admin/talks"
  defp return_path("show", talk), do: ~p"/admin/talks/#{talk}"
end
