defmodule MobileAppBackend.PubSubTests do
  use ExUnit.Case

  alias MobileAppBackend.PubSub

  setup do
    _dispatched_table = :ets.new(:fake_last_dispatched, [:set, :named_table])
    :ok
  end

  describe "group_pids_by_target_data/1" do
    test "groups by registy value" do
      assert %{
               {:fetch_1, :format_1} => [:pid_1, :pid_2],
               {:fetch_1, :format_2} => [:pid_3],
               {:fetch_2, :format_1} => [:pid_4]
             } ==
               PubSub.group_pids_by_target_data([
                 {:pid_1, {:fetch_1, :format_1}},
                 {:pid_2, {:fetch_1, :format_1}},
                 {:pid_3, {:fetch_1, :format_2}},
                 {:pid_4, {:fetch_2, :format_1}}
               ])
    end
  end

  describe "broadcast_latest_data/5" do
    test "broadcast latest data only broadcasts when data has changed" do
      PubSub.broadcast_latest_data(
        "latest_data",
        :new_data,
        {:fetch_keys, :format_fn},
        [self()],
        :fake_last_dispatched
      )

      assert_receive {:new_data, "latest_data"}

      # Doesn't re-send the same alerts that have already been seen
      PubSub.broadcast_latest_data(
        "latest_data",
        :new_data,
        {:fetch_keys, :format_fn},
        [self()],
        :fake_last_dispatched
      )

      refute_receive _

      PubSub.broadcast_latest_data(
        "even_newer_data",
        :new_data,
        {:fetch_keys, :format_fn},
        [self()],
        :fake_last_dispatched
      )

      assert_receive {:new_data, "even_newer_data"}
    end
  end
end
