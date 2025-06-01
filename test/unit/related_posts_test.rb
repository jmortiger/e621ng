# frozen_string_literal: true

require "test_helper"

class RelatedPostsTest < ActiveSupport::TestCase
  should "correctly determine the relative differences of tag arrays" do
    s = %w[a specific list of tags to search for]
    d1_1 = %w[specific list of tags to search for]
    d1_2 = %w[a specific listing of tags to search for]
    d1_3 = %w[a specific list of tags to search for now]
    d2 = %w[specific listing of tags to search for]
    d3 = %w[specific listing of tags to search for now]
    d_f = %w[and now for something completely different]
    assert_equal(0, RelatedPosts.l_distance(s, s, normalize: false))
    assert_equal(RelatedPosts::OPERATION_WEIGHTS[:deletion], RelatedPosts.l_distance(s, d1_1, normalize: false))
    assert_equal(RelatedPosts::OPERATION_WEIGHTS[:substitution], RelatedPosts.l_distance(s, d1_2, normalize: false))
    assert_equal(RelatedPosts::OPERATION_WEIGHTS[:insertion], RelatedPosts.l_distance(s, d1_3, normalize: false))
    assert_equal(2, RelatedPosts.l_distance(s, d2, normalize: false))
    assert_equal(3, RelatedPosts.l_distance(s, d3, normalize: false))
    assert_equal(0, RelatedPosts.l_distance(s, s, normalize: true))
    assert_equal(1, RelatedPosts.l_distance(s, d_f, normalize: true))
  end
end
