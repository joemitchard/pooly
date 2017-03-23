# pooly
A worker pool application
Mostly taken from The Little Elixir and OTP Guidebook by Benjamin Tan Wei Hao


Start application with `iex -S mix`

Api:
Pool name = `"PoolN"`

Get the current status of a pool:
`Pooly.status(pool_name)`

Check out a worker process from a pool:
`Pooly.checkout(pool_name)`
returns a worker pid

Check the worker process back into the pool:
`Pooly.check_in(poolname, worker_pid)`
