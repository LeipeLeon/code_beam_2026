defmodule LetItCrash.Tree do
  @moduledoc """
  The supervisor tree of attendees.

  Scanning someone's badge creates an undirected link. Your first link (if it
  would not create a cycle) also makes the other attendee your supervisor.
  """

  import Kernel, except: [exit: 1]
  import Ecto.Query

  alias Ecto.Changeset
  alias LetItCrash.{Events, Repo}
  alias LetItCrash.Attendees
  alias LetItCrash.Attendees.Attendee
  alias LetItCrash.Tree.Link

  @topic "tree"
  # Serialises all tree mutations so concurrent links can never form a cycle.
  @lock_key 0x7EEE

  def subscribe, do: Phoenix.PubSub.subscribe(LetItCrash.PubSub, @topic)

  def broadcast_changed,
    do: Phoenix.PubSub.broadcast(LetItCrash.PubSub, @topic, :tree_changed)

  @doc """
  Links `me` with the attendee `other_id`.
  """
  def link(%Attendee{id: id}, id), do: {:error, :self}

  def link(%Attendee{} = me, other_id) when is_integer(other_id) do
    Repo.transact(fn ->
      lock_tree()
      me = Repo.get!(Attendee, me.id)
      other = Repo.get(Attendee, other_id)

      cond do
        is_nil(other) ->
          {:error, :not_found}

        me.exited_at || other.exited_at ->
          {:error, :exited}

        true ->
          {a_id, b_id} = Enum.min_max([me.id, other.id])

          {inserted, _} =
            Repo.insert_all(
              Link,
              [%{a_id: a_id, b_id: b_id, inserted_at: DateTime.utc_now(:second)}],
              on_conflict: :nothing
            )

          cond do
            is_nil(me.supervisor_id) and not ancestor?(me.id, other) ->
              me = me |> Changeset.change(supervisor_id: other.id) |> Repo.update!()
              {:ok, {:supervised, me, other}}

            inserted == 1 ->
              {:ok, {:linked, me, other}}

            true ->
              {:ok, {:already_linked, me, other}}
          end
      end
    end)
    |> case do
      {:ok, {result, me, other}} ->
        announce_link(result, me, other)
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp announce_link(:supervised, me, other) do
    Events.broadcast(
      "#{Attendees.pid_label(me)} is now supervised by #{Attendees.pid_label(other)}"
    )

    broadcast_changed()
  end

  defp announce_link(:linked, me, other) do
    Events.broadcast("#{Attendees.pid_label(me)} ⇄ #{Attendees.pid_label(other)} linked")
    broadcast_changed()
  end

  defp announce_link(:already_linked, _me, _other), do: :ok

  # Is `ancestor_id` somewhere up `node`'s supervisor chain?
  defp ancestor?(ancestor_id, %Attendee{supervisor_id: ancestor_id}), do: true
  defp ancestor?(_ancestor_id, %Attendee{supervisor_id: nil}), do: false

  defp ancestor?(ancestor_id, %Attendee{supervisor_id: parent_id}) do
    case Repo.get(Attendee, parent_id) do
      nil -> false
      parent -> ancestor?(ancestor_id, parent)
    end
  end

  @doc """
  `exit(self(), :normal)`: marks the attendee as exited and re-parents its
  children to its former supervisor (or to the root).
  """
  def exit(%Attendee{} = attendee) do
    {:ok, {attendee, new_parent, restarted}} =
      Repo.transact(fn ->
        lock_tree()
        attendee = Repo.get!(Attendee, attendee.id)
        new_parent_id = attendee.supervisor_id

        exited =
          attendee
          |> Changeset.change(
            exited_at: DateTime.utc_now(:second),
            exit_reason: "normal",
            supervisor_id: nil
          )
          |> Repo.update!()

        {restarted, _} =
          from(a in Attendee, where: a.supervisor_id == ^attendee.id)
          |> Repo.update_all(set: [supervisor_id: new_parent_id])

        new_parent = new_parent_id && Repo.get(Attendee, new_parent_id)
        {:ok, {exited, new_parent, restarted}}
      end)

    new_parent_label =
      if new_parent, do: Attendees.pid_label(new_parent), else: "the application"

    Events.broadcast(
      "#{Attendees.pid_label(attendee)} #{attendee.nickname} exited :normal — " <>
        "#{restarted} children restarted under #{new_parent_label}"
    )

    broadcast_changed()
    {:ok, attendee}
  end

  @doc "Brings an exited attendee back."
  def restart(%Attendee{} = attendee) do
    attendee =
      attendee
      |> Changeset.change(exited_at: nil, exit_reason: nil)
      |> Repo.update!()

    Events.broadcast("#{Attendees.pid_label(attendee)} restarted (it's fine, that's the point)")
    broadcast_changed()
    {:ok, attendee}
  end

  @doc """
  The whole tree as a list of root nodes:
  `%{attendee: attendee, children: [node], link_count: integer}`.
  """
  def forest do
    attendees = Repo.all(from a in Attendee, order_by: a.id)
    counts = link_counts()
    by_parent = Enum.group_by(attendees, & &1.supervisor_id)
    build_nodes(Map.get(by_parent, nil, []), by_parent, counts)
  end

  defp build_nodes(attendees, by_parent, counts) do
    Enum.map(attendees, fn attendee ->
      %{
        attendee: attendee,
        children: build_nodes(Map.get(by_parent, attendee.id, []), by_parent, counts),
        link_count: Map.get(counts, attendee.id, 0)
      }
    end)
  end

  @doc "The most linked attendees: `[{attendee, count}]`."
  def top_linked(limit \\ 10) do
    counts = link_counts_query()

    Repo.all(
      from a in Attendee,
        join: c in subquery(counts),
        on: c.attendee_id == a.id,
        order_by: [desc: c.count, asc: a.id],
        limit: ^limit,
        select: {a, c.count}
    )
  end

  defp link_counts do
    link_counts_query()
    |> Repo.all()
    |> Map.new(&{&1.attendee_id, &1.count})
  end

  defp link_counts_query do
    ends =
      from(l in Link, select: %{attendee_id: l.a_id})
      |> union_all(^from(l in Link, select: %{attendee_id: l.b_id}))

    from e in subquery(ends),
      group_by: e.attendee_id,
      select: %{attendee_id: e.attendee_id, count: count()}
  end

  defp lock_tree, do: Repo.query!("SELECT pg_advisory_xact_lock($1)", [@lock_key])
end
