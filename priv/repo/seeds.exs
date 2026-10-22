# Script for populating the database. Safe to re-run: it only inserts into
# empty tables and never deletes anything.
#
#     mix run priv/repo/seeds.exs

alias LetItCrash.{Attendees, Repo, Talks}
alias LetItCrash.Attendees.Attendee
alias LetItCrash.Talks.Talk

if Repo.aggregate(Talk, :count) == 0 do
  # Placeholder schedule on today's conference date: the current hour and the
  # next, so the crash meter always has a talk running in dev.
  start = %{Talks.conference_now() | minute: 0, second: 0}
  slot_2 = NaiveDateTime.add(start, 1, :hour)
  slot_end = NaiveDateTime.add(start, 2, :hour)

  talks = [
    {start, slot_2, "Main Stage", "Hot Code Reloading My Marriage", "Ann Upgrade"},
    {start, slot_2, "Room B", "Nine Nines and Other Lies We Tell Management", "Dr. Ova Load"},
    {start, slot_2, "Room C", "It's Just a GenServer (It's Never Just a GenServer)",
     "Gen Serverson"},
    {slot_2, slot_end, "Main Stage", "Rewriting It in Rust: A Hostage Situation", "Ferris Crab"},
    {slot_2, slot_end, "Room B", "Mailbox Zero: Selective Receive for Your Inbox", "Mona Box"},
    {slot_2, slot_end, "Room C", "Live Demo Driven Development", "Murphy McLaw"}
  ]

  for {starts_at, ends_at, room, title, speaker} <- talks do
    {:ok, _} =
      Talks.create_talk(%{
        title: title,
        speaker: speaker,
        room: room,
        starts_at: starts_at,
        ends_at: ends_at
      })
  end
end

if Repo.aggregate(Attendee, :count) == 0 do
  {:ok, robert, _token} = Attendees.register("Robert the Supervisor")
  {:ok, jose, _token} = Attendees.register("José-ish")

  jose
  |> Ecto.Changeset.change(supervisor_id: robert.id)
  |> Repo.update!()
end
