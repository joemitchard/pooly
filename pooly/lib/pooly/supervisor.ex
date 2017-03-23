defmodule Pooly.Supervisor do
  @moduledoc """
  Top level supervisor for Pooly, kicks off a server and a pools supervisor
  """
  use Supervisor

  def start_link(pools_config) do
    Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def init(pools_config) do
    children = [
      supervisor(Pooly.PoolsSupervisor, []),
      worker(Pooly.Server, [pools_config])
    ]

    # if supervisor or server crash, all state will be lost, so all should come down
    opts = [strategy: :one_for_all]
    
    supervise(children, opts)
  end
end