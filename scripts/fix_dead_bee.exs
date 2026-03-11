# Fix bee-4bbddb status directly on disk
path = "/Users/mp/Projects/gitf-workspace/.gitf/store/gitf.etf"
data = File.read!(path) |> :erlang.binary_to_term()

bee = data[:bees]["bee-4bbddb"]
IO.puts("Bee status before: #{bee.status}")

bee = %{bee | status: "crashed"}
data = put_in(data, [:bees, "bee-4bbddb"], bee)

File.write!(path, :erlang.term_to_binary(data))
IO.puts("Bee status after: crashed")
