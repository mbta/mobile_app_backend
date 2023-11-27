defmodule RepoCache.SupervisorTest do
  @moduledoc false
  use ExUnit.Case

  alias RepoCache.Supervisor

  describe "start_link/1" do
    test "can start the supervisor" do
      assert {:ok, _pid} = Supervisor.start_link([])
    end
  end
end
