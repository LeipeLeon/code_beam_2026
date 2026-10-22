defmodule LetItCrash.Excuses do
  @moduledoc """
  Deterministic excuse / hallway-wisdom generator. The same `{kind, seed}`
  always produces the same text, so results can be shared as permalinks.
  """

  @kinds [:excuse, :wisdom]

  @talks [
    "this talk",
    "the keynote",
    "the 9am session",
    "the panel",
    "the lightning talks",
    "the workshop"
  ]

  @reasons [
    "my supervisor restarted me",
    "my mailbox has 40,000 unread messages",
    "I'm stuck in a selective receive",
    "I hit a netsplit with the coffee machine",
    "my process was OOM-killed by the buffet",
    "I'm hot-code-reloading my personality",
    "Dialyzer says I'm not allowed",
    "I'm waiting on a GenServer.call with :infinity timeout",
    "I got linked to someone in the hallway and can't trap exits",
    "I've exceeded my reductions for today"
  ]

  @consequences [
    "I'll be back in 5 seconds (default restart intensity)",
    "please send the slides to my mailbox",
    "I'll watch it in the hallway track",
    "consider this an :ignore",
    "I'll pattern-match on the recording later",
    "my supervisor will explain",
    "let it crash"
  ]

  @openers [
    "As the Erlang docs probably say:",
    "Ancient Ericsson proverb:",
    "Overheard at the coffee queue:",
    "Senior BEAM engineer, after 3 espressos:",
    "A wise process once told me:"
  ]

  @truths [
    "a crash is just a restart you haven't scheduled yet",
    "every problem is a GenServer if you squint",
    "there is no shared state, only shared regret",
    "the real supervision tree was the friends we linked along the way",
    "if it compiles, the Dialyzer will find something",
    "nine nines is just eight nines with confidence",
    "your mailbox is a queue of other people's priorities",
    "pattern matching is just saying no politely",
    "distributed systems are easy until the second node"
  ]

  @closers [
    "Let it crash.",
    "{:ok, :enlightened}",
    "** (EXIT) normal",
    "Restart intensity: high.",
    "Send this to someone's mailbox.",
    ":ok"
  ]

  def kinds, do: @kinds

  def random_seed, do: :rand.uniform(1_000_000_000)

  def generate(:excuse, seed) when is_integer(seed) and seed > 0 do
    [talk, reason, consequence] = pick(seed, [@talks, @reasons, @consequences])
    "Sorry, can't make #{talk} — #{reason}, so #{consequence}."
  end

  def generate(:wisdom, seed) when is_integer(seed) and seed > 0 do
    [opener, truth, closer] = pick(seed, [@openers, @truths, @closers])
    "#{opener} #{truth}. #{closer}"
  end

  # Picks one entry from each pool using an explicit, seeded PRNG state.
  defp pick(seed, pools) do
    {picks, _state} =
      Enum.map_reduce(pools, :rand.seed_s(:exsss, seed), fn pool, state ->
        {i, state} = :rand.uniform_s(length(pool), state)
        {Enum.at(pool, i - 1), state}
      end)

    picks
  end
end
