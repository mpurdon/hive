# Reset the stuck job directly on disk, bypassing Store GenServer
path = "/Users/mp/Projects/gitf-workspace/.gitf/store/gitf.etf"
data = File.read!(path) |> :erlang.binary_to_term()

job = data[:jobs]["job-c54c34"]
IO.puts("Before: #{job.status}")

job = %{job | status: "pending", bee_id: nil}
data = put_in(data, [:jobs, "job-c54c34"], job)

binary = :erlang.term_to_binary(data)
File.write!(path, binary)

# Verify
data2 = File.read!(path) |> :erlang.binary_to_term()
IO.puts("After: #{data2[:jobs]["job-c54c34"].status}")
