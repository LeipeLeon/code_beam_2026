defmodule LetItCrashWeb.JoinHTML do
  use LetItCrashWeb, :html

  def new(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm space-y-6 py-8">
        <div class="text-center space-y-2">
          <h1 class="text-3xl font-black font-mono">spawn/3 yourself</h1>
          <p class="text-base-content/70">
            Pick a nickname. No password, no email. Lose your cookie, lose your process.
          </p>
        </div>

        <.form for={@form} id="join-form" action={~p"/join"}>
          <.input field={@form[:nickname]} label="Nickname" autocomplete="off" required />
          <.button variant="primary" class="btn btn-primary w-full" phx-disable-with="Spawning...">
            Spawn process
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
