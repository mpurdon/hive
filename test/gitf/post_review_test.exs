defmodule GiTF.PostReviewTest do
  use ExUnit.Case, async: false

  alias GiTF.PostReview
  alias GiTF.Store
  alias GiTF.Test.StoreHelper

  setup do
    data_dir = Path.join(System.tmp_dir!(), "gitf_test_post_review_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(data_dir)
    StoreHelper.restart_store!(data_dir)

    on_exit(fn ->
      StoreHelper.stop_store()
      File.rm_rf!(data_dir)
    end)

    :ok
  end

  defp create_quest(opts \\ %{}) do
    goal = Map.get(opts, :goal, "Test quest")
    comb_id = Map.get(opts, :comb_id, "cmb_test")

    comb_attrs = Map.get(opts, :comb, %{})
    comb = Map.merge(%{id: comb_id, path: System.tmp_dir!(), name: "test"}, comb_attrs)
    Store.insert(:combs, comb)

    {:ok, quest} = GiTF.Quests.create(%{goal: goal, comb_id: comb_id})
    quest
  end

  describe "start_review/1" do
    test "creates an active review record" do
      quest = create_quest()
      {:ok, review} = PostReview.start_review(quest.id)

      assert review.quest_id == quest.id
      assert review.status == "active"
      assert review.expires_at != nil
    end

    test "review appears in active_reviews" do
      quest = create_quest()
      {:ok, _} = PostReview.start_review(quest.id)

      reviews = PostReview.active_reviews()
      assert length(reviews) == 1
      assert hd(reviews).quest_id == quest.id
    end
  end

  describe "enabled?/1" do
    test "returns false when comb not found" do
      refute PostReview.enabled?("nonexistent")
    end

    test "returns false when post_review not set" do
      Store.insert(:combs, %{id: "cmb_no_review", path: "/tmp", name: "no-review"})
      refute PostReview.enabled?("cmb_no_review")
    end

    test "returns true when post_review is true" do
      Store.insert(:combs, %{id: "cmb_with_review", path: "/tmp", name: "with-review", post_review: true})
      assert PostReview.enabled?("cmb_with_review")
    end
  end

  describe "close_review/1" do
    test "marks review as completed" do
      quest = create_quest()
      {:ok, _} = PostReview.start_review(quest.id)

      assert length(PostReview.active_reviews()) == 1

      :ok = PostReview.close_review(quest.id)

      assert length(PostReview.active_reviews()) == 0
    end
  end

  describe "expired?/1" do
    test "returns false for fresh review" do
      review = %{expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)}
      refute PostReview.expired?(review)
    end

    test "returns true for expired review" do
      review = %{expires_at: DateTime.add(DateTime.utc_now(), -1, :second)}
      assert PostReview.expired?(review)
    end
  end

  describe "check_regressions/1" do
    test "returns :clean when no validation command" do
      quest = create_quest()
      {:ok, _} = PostReview.start_review(quest.id)

      assert {:ok, :clean} = PostReview.check_regressions(quest.id)
    end

    test "returns :clean when validation passes" do
      quest = create_quest(%{comb: %{validation_command: "true"}})
      {:ok, _} = PostReview.start_review(quest.id)

      assert {:ok, :clean} = PostReview.check_regressions(quest.id)
    end

    test "returns :regression when validation fails" do
      quest = create_quest(%{comb: %{validation_command: "echo 'test failed' && exit 1"}})
      {:ok, _} = PostReview.start_review(quest.id)

      assert {:ok, :regression, findings} = PostReview.check_regressions(quest.id)
      assert String.contains?(findings, "test failed")
    end
  end

  describe "handle_regression/2" do
    test "creates follow-up quest and updates review" do
      quest = create_quest()
      {:ok, _} = PostReview.start_review(quest.id)

      {:ok, followup} = PostReview.handle_regression(quest.id, "Tests failed")

      assert String.contains?(followup.goal, "Fix regression")
      assert followup.comb_id == quest.comb_id

      # Review should be updated
      assert length(PostReview.active_reviews()) == 0
    end
  end

  describe "Reputation.apply_regression_penalty/1" do
    test "marks jobs with regression_detected" do
      quest = create_quest()

      {:ok, job} = GiTF.Jobs.create(%{
        title: "Test job",
        quest_id: quest.id,
        comb_id: quest.comb_id
      })

      # Initially no regression flag
      {:ok, fresh_job} = GiTF.Jobs.get(job.id)
      refute Map.get(fresh_job, :regression_detected, false)

      # Apply penalty
      GiTF.Reputation.apply_regression_penalty(quest.id)

      # Now regression flag should be set
      {:ok, updated_job} = GiTF.Jobs.get(job.id)
      assert Map.get(updated_job, :regression_detected) == true
    end
  end
end
