defmodule LetItCrash.Events do
  @moduledoc """
  Global ticker of funny one-liners, broadcast on the `"events"` topic as
  `{:event, %{id: integer, text: String.t(), at: DateTime.t()}}`.
  """

  @topic "events"

  def subscribe, do: Phoenix.PubSub.subscribe(LetItCrash.PubSub, @topic)

  def broadcast(text) when is_binary(text) do
    event = %{
      id: System.unique_integer([:positive]),
      text: text,
      at: DateTime.utc_now(:second)
    }

    Phoenix.PubSub.broadcast(LetItCrash.PubSub, @topic, {:event, event})
  end
end
