defmodule LetItCrash.Talks do
  @moduledoc """
  The Talks context.
  """

  import Ecto.Query, warn: false
  alias LetItCrash.Repo

  alias LetItCrash.Talks.Talk

  @doc """
  Returns the list of talks.

  ## Examples

      iex> list_talks()
      [%Talk{}, ...]

  """
  def list_talks do
    Repo.all(from t in Talk, order_by: [asc: t.starts_at, asc: t.room])
  end

  @doc """
  Current wall-clock time in the conference time zone, as a naive datetime.

  Talk times are stored as conference-local wall-clock times, so this is the
  value to compare them against.
  """
  def conference_now do
    Application.fetch_env!(:let_it_crash, :conference_time_zone)
    |> DateTime.now!()
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
  end

  @doc """
  Returns the talk running in `room` at `now` (start inclusive, end exclusive), or nil.
  """
  def current_talk(room, now \\ conference_now()) do
    Repo.one(
      from t in Talk,
        where: t.room == ^room and t.starts_at <= ^now and t.ends_at > ^now,
        order_by: [desc: t.starts_at],
        limit: 1
    )
  end

  @doc """
  Returns all distinct room names, sorted.
  """
  def rooms do
    Repo.all(from t in Talk, distinct: true, select: t.room, order_by: t.room)
  end

  @doc """
  Gets a single talk.

  Raises `Ecto.NoResultsError` if the Talk does not exist.

  ## Examples

      iex> get_talk!(123)
      %Talk{}

      iex> get_talk!(456)
      ** (Ecto.NoResultsError)

  """
  def get_talk!(id), do: Repo.get!(Talk, id)

  @doc """
  Creates a talk.

  ## Examples

      iex> create_talk(%{field: value})
      {:ok, %Talk{}}

      iex> create_talk(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_talk(attrs) do
    %Talk{}
    |> Talk.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a talk.

  ## Examples

      iex> update_talk(talk, %{field: new_value})
      {:ok, %Talk{}}

      iex> update_talk(talk, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_talk(%Talk{} = talk, attrs) do
    talk
    |> Talk.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a talk.

  ## Examples

      iex> delete_talk(talk)
      {:ok, %Talk{}}

      iex> delete_talk(talk)
      {:error, %Ecto.Changeset{}}

  """
  def delete_talk(%Talk{} = talk) do
    Repo.delete(talk)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking talk changes.

  ## Examples

      iex> change_talk(talk)
      %Ecto.Changeset{data: %Talk{}}

  """
  def change_talk(%Talk{} = talk, attrs \\ %{}) do
    Talk.changeset(talk, attrs)
  end
end
