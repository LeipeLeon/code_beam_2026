defmodule LetItCrashWeb.AttendeeComponents do
  @moduledoc """
  Shared rendering of attendees: always the fake PID followed by the nickname.
  """
  use Phoenix.Component

  alias LetItCrash.Attendees

  attr :attendee, :map, required: true
  attr :class, :any, default: nil

  def attendee_label(assigns) do
    ~H"""
    <span class={["inline-flex items-baseline gap-1.5", @class]}>
      <code class="font-mono text-xs text-primary">{Attendees.pid_label(@attendee)}</code>
      <span class="font-semibold">{@attendee.nickname}</span>
    </span>
    """
  end
end
