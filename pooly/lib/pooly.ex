defmodule Pooly do
  @moduledoc """
  Documentation for Pooly.
  """
  use Application

  alias Pooly.Server

  @timeout 5000

  def start(_type, _args) do
    pools_config = [
      [name: "Pool1",
        mfa: {SampleWorker, :start_link, []}, 
        size: 2,
        max_overflow: 1
      ],
      [name: "Pool2",
        mfa: {SampleWorker, :start_link, []}, 
        size: 3,
        max_overflow: 0
      ],
      [name: "Pool3",
        mfa: {SampleWorker, :start_link, []}, 
        size: 4,
        max_overflow: 0
      ]
    ]
    start_pools(pools_config)
  end

  def start_pools(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end

  def checkout(pool_name, block \\ true, timeout \\ @timeout) do
    Server.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Server.status(pool_name)
  end
end
