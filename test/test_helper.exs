# Phase 1: Start repo WITHOUT sandbox to run migrations.
# SQLite with pool_size 1 + sandbox = migration Task contention,
# so we migrate first against a plain pool, then restart with sandbox.
{:ok, pid} = Hive.Repo.start_link()

Ecto.Migrator.run(
  Hive.Repo,
  Hive.Repo.Migrations.all(),
  :up,
  all: true,
  log: false
)

# Phase 2: Stop and restart with the Sandbox pool for test isolation.
GenServer.stop(pid)

{:ok, _} = Hive.Repo.start_link(pool: Ecto.Adapters.SQL.Sandbox)
Ecto.Adapters.SQL.Sandbox.mode(Hive.Repo, :manual)

ExUnit.start()
