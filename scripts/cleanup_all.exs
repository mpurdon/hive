path = "/Users/mp/Projects/gitf-workspace/.gitf/store/gitf.etf"
data = File.read(path) |> elem(1) |> :erlang.binary_to_term()

bees = data[:bees] || %{}
jobs = data[:jobs] || %{}

bees = Map.new(bees, fn {id, b} ->
  if b.status in ["working", "provisioning"] do
    IO.puts("bee #{id}: #{b.status} -> crashed")
    {id, %{b | status: "crashed"}}
  else
    {id, b}
  end
end)

jobs = Map.new(jobs, fn {id, j} ->
  if j.status in ["running", "assigned"] do
    IO.puts("job #{id}: #{j.status} -> pending")
    {id, %{j | status: "pending", bee_id: nil}}
  else
    {id, j}
  end
end)

data = %{data | bees: bees, jobs: jobs}
File.write(path, :erlang.term_to_binary(data))
IO.puts("Done.")
