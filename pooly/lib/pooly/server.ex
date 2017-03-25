defmodule Pooly.Server do
  @moduledoc """
  A server to handle incoming and outgoing requests for workers.
  Talks with the worker_supervisor to handle worker processes, maintaing a state of available and 
  in use workers
  """
  use GenServer
  import Supervisor.Spec

  # Api

  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  # These functions call the requested pool from a dynamically created atom name
  def status(pool_name) do
    Pooly.PoolServer.status(pool_name)
  end

  def checkout(pool_name, block, timeout) do
    Pooly.PoolServer.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.PoolServer.checkin(pool_name, worker_pid)
  end

  # Callbacks

  @doc """
  Iterates through the configurations and sends :start_pool msg to itself
  """
  def init(pools_config) do
    pools_config
    |> Enum.each(fn (pool_config) ->
        send(self(), {:start_pool, pool_config})
      end)

    {:ok, pools_config}
  end

  @doc """
  On receiving message, passes `pool_config` to PoolsSupervisor
  starts a child PoolSupervisor based on the given `pool_config`
  """
  def handle_info({:start_pool, pool_config}, state) do
    {:ok, _pool_sup} = Supervisor.start_child(Pooly.PoolsSupervisor, supervisor_spec(pool_config))
    {:noreply, state}
  end

  # Helper Functions

  defp supervisor_spec(pool_config) do
    opts = [id: :"#{pool_config[:name]}Supervisor"]
    supervisor(Pooly.PoolSupervisor, [pool_config], opts)
  end

end