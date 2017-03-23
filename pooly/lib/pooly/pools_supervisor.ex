defmodule Pooly.PoolsSupervisor do
  @moduledoc """
  Supervisor for individual pools
  """
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do

    # Set one_for_one so a crash only affects the individual pool, not all
    opts = [
      strategy: :one_for_one
    ]

    supervise([], opts)
  end

end