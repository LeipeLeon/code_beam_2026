defmodule LetItCrash.TalksFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LetItCrash.Talks` context.
  """

  @doc """
  Generate a talk.
  """
  def talk_fixture(attrs \\ %{}) do
    {:ok, talk} =
      attrs
      |> Enum.into(%{
        ends_at: ~N[2026-10-21 13:54:00],
        room: "some room",
        speaker: "some speaker",
        starts_at: ~N[2026-10-21 12:54:00],
        title: "some title"
      })
      |> LetItCrash.Talks.create_talk()

    talk
  end
end
