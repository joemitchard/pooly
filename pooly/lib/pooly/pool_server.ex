defmodule Pooly.PoolServer do
  @moduledoc """
  A server to handle incoming and outgoing requests for workers.
  Talks with the worker_supervisor to handle worker processes, maintaing a state of available and 
  in use workers
  """
  use GenServer
  import Supervisor.Spec

  defmodule State do
    defstruct pool_sup: nil, worker_sup: nil, monitors: nil, size: nil,  workers: nil, name: nil, mfa: nil
  end
  
  # Api

  def start_link(pool_sup, pool_config) do
    GenServer.start_link(__MODULE__, [pool_sup, pool_config], name: name(pool_config[:name]))
  end

  def status(pool_name) do
    GenServer.call(name(pool_name), :status)
  end

  def checkout(pool_name) do
    GenServer.call(name(pool_name), :checkout)
  end

  def checkin(pool_name, worker_pid) do
    GenServer.cast(name(pool_name), {:checkin, worker_pid})
  end

  # Callbacks

  @doc """
  Kick off the server, inserting accepted args into the state
  a valid pool_config looks like [mfa: {ModuleName, :fun, []}, size: n]
  """
  def init([pool_sup, pool_config]) when is_pid(pool_sup) do
    Process.flag(:trap_exit, true)
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{pool_sup: pool_sup, monitors: monitors})
  end

  def init([{:name, name}|rest], state) do
    init(rest,  %{state | name: name})
  end

  def init([{:mfa, mfa}|rest], state) do
    init(rest, %{state | mfa: mfa})
  end

  def init([{:size, size}|rest], state) do
    init(rest, %{state | size: size})
  end

  # ignore other options
  def init([_|rest], state) do
    init(rest, state)
  end

  def init([], state) do
    send(self(), :start_worker_supervisor)
    {:ok, state}
  end

  @doc """
  Retreives information from the server about count of available/active workers
  """
  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end

  @doc """
  Checks a worker out of the availalbe workers list and adds it to the active pool
  Returns :noproc if no worker is available or a pid if there is
  """
  def handle_call(:checkout, {from_pid, _ref}, %{workers: workers, monitors: monitors} = state) do
    case workers do
      [worker|rest] ->
        ref = Process.monitor(from_pid)
        true = :ets.insert(monitors, {worker, ref})
        {:reply, worker, %{state | workers: rest}}
      [] ->
        {:reply, :noproc, state}
    end
  end

  @doc """
  Check in a worker to the pool, adds it to the list of available workers
  """
  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, %{state | workers: [pid|workers]}}
      [] ->
        {:noreply, state}
    end    
  end

  @doc """
  Handle message to start the worker supervisor
  """
  def handle_info(:start_worker_supervisor, state = %{pool_sup: pool_sup, name: name, mfa: mfa, size: size}) do
    {:ok, worker_sup} = Supervisor.start_child(pool_sup, supervisor_spec(name, mfa))

    workers = prepopulate(size, worker_sup)

    {:noreply, %{state | worker_sup: worker_sup, workers: workers}}
  end

  @doc """
  Handle workers that have finished work
  """
  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] ->
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid|workers]}
        {:noreply, new_state}
      [[]] ->
        {:noreply, state}
    end
  end

  @doc """
  Handles worker supervisor crashes
  """
  def handle_info({:EXIT, worker_sup, reason}, state = %{worker_sup: worker_sup}) do
    {:stop, reason, state}
  end

  @doc """
  Handle workers that have crashed, restarting them
  """
  def handle_info({:EXIT, pid, _reason}, state = %{monitors: monitors, workers: workers, pool_sup: pool_sup}) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] ->
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [new_worker(pool_sup) | workers]}
        {:noreply, new_state}
      [[]] ->
        {:noreply, state}
    end
  end

  def terminate(_reason, _state) do
    :ok
  end

  # Helper Functions

  defp name(pool_name) do
    :"#{pool_name}Server"
  end

  defp supervisor_spec(name, mfa) do
    opts = [id: name <> "WorkerSupervisor", restart: :temporary]
    supervisor(Pooly.WorkerSupervisor, [self(), mfa], opts)
  end

  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end

  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end

  defp prepopulate(size, sup, workers) do
    prepopulate(size - 1, sup, [new_worker(sup) | workers])
  end

  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]])
    worker
  end

end
