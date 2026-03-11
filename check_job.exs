store_path = "/Users/mp/Projects/gitf-workspace/.gitf/store/gitf.etf"
data = File.read!(store_path) |> :erlang.binary_to_term()

job = get_in(data, [:jobs, "job-0208de"])
if job do
  IO.puts("Job: #{job.id}")
  IO.puts("Title: #{job[:title]}")
  IO.puts("Status: #{job[:status]}")
  IO.puts("Phase: #{job[:phase]}")
  IO.puts("Phase job: #{job[:phase_job]}")
  IO.puts("Quest ID: #{job[:quest_id]}")
  IO.puts("Bee ID: #{job[:bee_id]}")
  IO.puts("Error: #{inspect(job[:error])}")
  IO.puts("Failure reason: #{inspect(job[:failure_reason])}")
  IO.puts("\nFull job:")
  IO.inspect(job, pretty: true, limit: :infinity)
else
  IO.puts("Job not found")
end

bee = get_in(data, [:bees, "bee-c09b6f"])
if bee do
  IO.puts("\n\nBee: #{bee.id}")
  IO.puts("Status: #{bee[:status]}")
  IO.puts("Error: #{inspect(bee[:error])}")
  IO.puts("Exit reason: #{inspect(bee[:exit_reason])}")
  IO.puts("\nFull bee:")
  IO.inspect(bee, pretty: true, limit: :infinity)
else
  IO.puts("\nBee not found")
end
