defmodule Pooly.PoolSupervisor do
  @moduledoc """
  A supervisor for an individual pool and pool_server
  """
  use Supervisor

  @doc """
  Starts link to supervisor, naming it the {PoolName}Supervisor
  Eg: Pool1Supervisor
  """
  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config, name: :"#{pool_config[:name]}Supervisor")
  end

  def init(pool_config) do
    # If anything in this pools tree fails, restart all
    opts = [
      strategy: :one_for_all
    ]

    children = [
      worker(Pooly.PoolServer, [self(), pool_config])
    ]

    supervise(children, opts)
  end
end