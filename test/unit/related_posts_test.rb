# frozen_string_literal: true

require "test_helper"

class RelatedPostsTest < ActiveSupport::TestCase
  WEIGHTS = RelatedPosts::OPERATION_WEIGHTS
  CASES_STR = {
    original: { case: "tennis_ace", operations: [] },
    deletion: { case: "ennis_ace", operations: [:deletion] },
    insertion: { case: "tennis_face", operations: [:insertion] },
    substitution: { case: "tennis_ate", operations: [:substitution] },
    deletion_insertion: { case: "ennis_face", operations: %i[deletion insertion] },
    deletion_substitution: { case: "ennis_ate", operations: %i[substitution deletion] },
    insertion_substitution: { case: "tennis_fate", operations: %i[insertion substitution] },
    different: { case: "somEThINg-dIffErENT", operations: %i[substitution substitution substitution substitution substitution substitution substitution substitution substitution substitution insertion insertion insertion insertion insertion insertion insertion insertion insertion] },
  }.freeze
  CASES_TAGS = {
    original: { case: %w[aaa bbb ccc ddd fff], operations: [] },
    deletion: { case: %w[bbb ccc ddd fff], operations: [:deletion] },
    insertion: { case: %w[aaa bbb ccc ddd eee fff], operations: [:insertion] },
    substitution: { case: %w[aaa b_b ccc ddd fff], operations: [:substitution] },
    deletion_insertion: { case: %w[bbb ccc ddd eee fff], operations: %i[deletion insertion] },
    deletion_substitution: { case: %w[b_b ccc ddd fff], operations: %i[deletion substitution] },
    insertion_substitution: { case: %w[aaa b_b ccc ddd eee fff], operations: %i[insertion substitution] },
    all: { case: %w[b_b ccc ddd eee fff], operations: %i[deletion insertion substitution] },
    different: { case: %w[ttt uuu vvv www xxx yyy zzz], operations: %i[substitution substitution substitution substitution substitution substitution substitution substitution substitution substitution insertion insertion insertion insertion insertion insertion insertion insertion insertion] },
  }.freeze
  def self.get_projected_distance(case_hash, default_case: nil, weights: WEIGHTS, normalize: false)
    unless default_case
      if case_hash[:case].is_a?(Array)
        default_case = CASES_TAGS[:original][:case]
      else
        default_case = CASES_STR[:original][:case]
      end
    end
    t = case_hash[:operations].inject(0) { |acc, e1| acc + weights[e1] }
    if normalize
      t /= (RelatedPosts::MAX_WEIGHT * [case_hash[:case].length, default_case.length].max)
    end
    t
  end

  # _eventually
  should "correctly determine the relative differences of tag arrays" do
    s = %w[a specific list of tags to search for].freeze
    d1_1 = %w[specific list of tags to search for].freeze
    d1_2 = %w[a specific listing of tags to search for].freeze
    d1_3 = %w[a specific list of tags to search for now].freeze
    d2 = %w[specific listing of tags to search for].freeze
    d3 = %w[specific listing of tags to search for now].freeze
    d_f = %w[and now for something completely different].freeze
    # puts "#{s}"
    # puts "#{d1_1}"
    # puts "#{d1_2}"
    # puts "#{d1_3}"
    # puts "#{d2}"
    # puts "#{d3}"
    # puts "#{d_f}"
    assert_equal(0, RelatedPosts.l_distance(s, s, normalize: false))
    assert_equal(WEIGHTS[:deletion], RelatedPosts.l_distance(s, d1_1, normalize: false))
    assert_equal(WEIGHTS[:substitution], RelatedPosts.l_distance(s, d1_2, normalize: false))
    assert_equal(WEIGHTS[:insertion], RelatedPosts.l_distance(s, d1_3, normalize: false))
    assert_equal(2, RelatedPosts.l_distance(s, d2, normalize: false))
    assert_equal(3, RelatedPosts.l_distance(s, d3, normalize: false))
    assert_equal(0, RelatedPosts.l_distance(s, s, normalize: true))
    assert_equal(1, RelatedPosts.l_distance(s, d_f, normalize: true))
  end

  should "correctly determine the relative differences of strings" do
    assert_equal(0, RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:original][:case], normalize: false))
    assert_equal(WEIGHTS[:deletion], RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:deletion][:case], normalize: false))
    assert_equal(WEIGHTS[:insertion], RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:insertion][:case], normalize: false))
    assert_equal(WEIGHTS[:substitution], RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:substitution][:case], normalize: false))
    assert_equal(2, RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:deletion_insertion][:case], normalize: false))
    assert_equal(0, RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:original][:case], normalize: true))
    assert_equal(1, RelatedPosts.l_distance(CASES_STR[:original][:case], CASES_STR[:different][:case], normalize: true))
  end

  context "Post Similarity" do
    context "Search" do
      setup do
        @p0 = create(:post, tag_string: "aaa bbb ccc ddd fff")
        @p1 = create(:post, tag_string: "bbb ccc ddd fff")
        @p2 = create(:post, tag_string: "aaa bbb ccc ddd eee fff")
        @p3 = create(:post, tag_string: "aaa b_b ccc ddd fff")
        @p4 = create(:post, tag_string: "bbb ccc ddd eee fff")
        @p5 = create(:post, tag_string: "b_b ccc ddd fff")
        @p6 = create(:post, tag_string: "aaa b_b ccc ddd eee fff")
        @p7 = create(:post, tag_string: "b_b ccc ddd eee fff")
        @p8 = create(:post, tag_string: "ttt uuu vvv www xxx yyy zzz")
      end

      should "work by sampling" do
        expected = [@p0, @p1, @p2, @p3]
        results = RelatedPosts.get_from_post_and_sample(@p0, sample_size: 9 * 2, max_results: 4)
        assert(results.all? { |e| expected.include?(e) }, "Expected #{expected.map(&:id)}, got #{results.map(&:id)}; #{RelatedPosts.calculate_from_post_and_sample(@p0, sample_size: 9 * 2, max_results: 4)}")
        assert_equal(expected.first, results.first)
      end
    end
  end
end
