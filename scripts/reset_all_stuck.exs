# Reset all stuck bees and jobs directly on disk
path = "/Users/mp/Projects/gitf-workspace/.gitf/store/gitf.etf"
data = File.read!(path) |> :erlang.binary_to_term()

# Fix all "working" bees -> crashed
bees = data[:bees] || %{}
fixed_bees = Map.new(bees, fn {id, bee} ->
  if bee.status == "working" do
    IO.puts("bee #{id}: working -> crashed")
    {id, %{bee | status: "crashed"}}
  else
    {id, bee}
  end
end)

# Fix all "running" jobs -> failed, then pending
jobs = data[:jobs] || %{}
fixed_jobs = Map.new(jobs, fn {id, job} ->
  if job.status == "running" do
    IO.puts("job #{id}: running -> pending (was #{job.title})")
    {id, %{job | status: "pending", bee_id: nil}}
  else
    {id, job}
  end
end)

data = %{data | bees: fixed_bees, jobs: fixed_jobs}
File.write!(path, :erlang.term_to_binary(data))

IO.puts("\nDone. All stuck bees crashed, all running jobs reset to pending.")
