defmodule LetItCrash.TalksTest do
  use LetItCrash.DataCase

  alias LetItCrash.Talks

  describe "talks" do
    alias LetItCrash.Talks.Talk

    import LetItCrash.TalksFixtures

    @invalid_attrs %{title: nil, speaker: nil, room: nil, starts_at: nil, ends_at: nil}

    test "list_talks/0 returns all talks" do
      talk = talk_fixture()
      assert Talks.list_talks() == [talk]
    end

    test "get_talk!/1 returns the talk with given id" do
      talk = talk_fixture()
      assert Talks.get_talk!(talk.id) == talk
    end

    test "create_talk/1 with valid data creates a talk" do
      valid_attrs = %{
        title: "some title",
        speaker: "some speaker",
        room: "some room",
        starts_at: ~N[2026-10-21 12:54:00],
        ends_at: ~N[2026-10-21 13:54:00]
      }

      assert {:ok, %Talk{} = talk} = Talks.create_talk(valid_attrs)
      assert talk.title == "some title"
      assert talk.speaker == "some speaker"
      assert talk.room == "some room"
      assert talk.starts_at == ~N[2026-10-21 12:54:00]
      assert talk.ends_at == ~N[2026-10-21 13:54:00]
    end

    test "create_talk/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Talks.create_talk(@invalid_attrs)
    end

    test "update_talk/2 with valid data updates the talk" do
      talk = talk_fixture()

      update_attrs = %{
        title: "some updated title",
        speaker: "some updated speaker",
        room: "some updated room",
        starts_at: ~N[2026-10-22 12:54:00],
        ends_at: ~N[2026-10-22 13:54:00]
      }

      assert {:ok, %Talk{} = talk} = Talks.update_talk(talk, update_attrs)
      assert talk.title == "some updated title"
      assert talk.speaker == "some updated speaker"
      assert talk.room == "some updated room"
      assert talk.starts_at == ~N[2026-10-22 12:54:00]
      assert talk.ends_at == ~N[2026-10-22 13:54:00]
    end

    test "update_talk/2 with invalid data returns error changeset" do
      talk = talk_fixture()
      assert {:error, %Ecto.Changeset{}} = Talks.update_talk(talk, @invalid_attrs)
      assert talk == Talks.get_talk!(talk.id)
    end

    test "delete_talk/1 deletes the talk" do
      talk = talk_fixture()
      assert {:ok, %Talk{}} = Talks.delete_talk(talk)
      assert_raise Ecto.NoResultsError, fn -> Talks.get_talk!(talk.id) end
    end

    test "change_talk/1 returns a talk changeset" do
      talk = talk_fixture()
      assert %Ecto.Changeset{} = Talks.change_talk(talk)
    end
  end
end
