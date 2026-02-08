defmodule Hive.ValidatorTest do
  use ExUnit.Case, async: true

  alias Hive.Validator

  describe "build_validation_prompt/2" do
    test "builds a prompt with job title and diff" do
      job = %{
        id: "job-123",
        title: "Fix the login bug",
        description: "Users can't log in when password has special chars",
        status: "done",
        quest_id: "qst-1",
        comb_id: "cmb-1"
      }

      diff = """
      --- a/lib/auth.ex
      +++ b/lib/auth.ex
      @@ -10,3 +10,5 @@
      -  def check(pass), do: :error
      +  def check(pass) do
      +    URI.decode(pass) |> verify()
      +  end
      """

      prompt = Validator.build_validation_prompt(job, diff)

      assert prompt =~ "Fix the login bug"
      assert prompt =~ "special chars"
      assert prompt =~ "lib/auth.ex"
      assert prompt =~ ~s("verdict")
    end

    test "handles nil description" do
      job = %{
        id: "job-456",
        title: "Quick fix",
        description: nil,
        status: "done",
        quest_id: "qst-1",
        comb_id: "cmb-1"
      }

      prompt = Validator.build_validation_prompt(job, "some diff")
      assert prompt =~ "Quick fix"
      assert prompt =~ "some diff"
    end
  end

  describe "run_custom_validation/2" do
    test "runs a passing command" do
      tmp_dir = Path.join(System.tmp_dir!(), "hive_val_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)
      on_exit(fn -> File.rm_rf(tmp_dir) end)

      cell = %{
        id: "cel-test",
        worktree_path: tmp_dir,
        bee_id: "bee-1",
        comb_id: "cmb-1",
        branch: "test",
        status: "active"
      }

      assert :ok = Validator.run_custom_validation(cell, "true")
    end

    test "returns error for failing command" do
      tmp_dir = Path.join(System.tmp_dir!(), "hive_val_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)
      on_exit(fn -> File.rm_rf(tmp_dir) end)

      cell = %{
        id: "cel-test",
        worktree_path: tmp_dir,
        bee_id: "bee-1",
        comb_id: "cmb-1",
        branch: "test",
        status: "active"
      }

      assert {:error, msg} = Validator.run_custom_validation(cell, "false")
      assert msg =~ "exit 1"
    end
  end
end
