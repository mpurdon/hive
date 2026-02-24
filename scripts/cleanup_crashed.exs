# Remove all crashed/stopped bees from the Store
path = "/Users/mp/Projects/hive-workspace/.hive/store/hive.etf"
data = File.read!(path) |> :erlang.binary_to_term()

bees = data[:bees] || %{}
{keep, remove} = Map.split_with(bees, fn {_id, bee} -> bee.status == "working" end)

IO.puts("Keeping #{map_size(keep)} working bees")
IO.puts("Removing #{map_size(remove)} dead bees:")
for {id, bee} <- remove, do: IO.puts("  #{id} [#{bee.status}]")

data = %{data | bees: keep}
File.write!(path, :erlang.term_to_binary(data))
IO.puts("Done.")
