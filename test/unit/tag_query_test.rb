# frozen_string_literal: true

require "test_helper"

class TagQueryTest < ActiveSupport::TestCase
  should "scan a query" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[~AAa -BBB* -bbb*], TagQuery.scan("~AAa -BBB* -bbb*"))
    # Order is now preserved
    assert_equal(["aaa", 'test:"with spaces"', "def"], TagQuery.scan('aaa test:"with spaces" def'))
    # assert_equal(['test:"with spaces"', "aaa", "def"], TagQuery.scan('aaa test:"with spaces" def'))
  end

  should "scan a grouped query" do
    # Pull out top-level group
    assert_equal(%w[aaa bbb], TagQuery.scan_search("( aaa bbb )"))
    # Don't pull out top-level group w/ modifier
    assert_equal(["-( aaa bbb )"], TagQuery.scan_search("-( aaa bbb )"))
    assert_equal(["( aaa )", "-( bbb )"], TagQuery.scan_search("( aaa ) -( bbb )"))
    assert_equal(["~( AAa -BBB* )", "-bbb*"], TagQuery.scan_search("~( AAa -BBB* ) -bbb*"))
    # assert_equal(["~AAa", "-BBB*", "-bbb*"], TagQuery.scan_search("~AAa -BBB* -bbb*"))
    assert_equal(["aaa", 'test:"with spaces"', "def"], TagQuery.scan_search('aaa test:"with spaces" def'))
  end

  should "scan a grouped query recursively" do
    assert_equal(["(", "aaa", "bbb", ")"], TagQuery.scan_recursive("( aaa bbb )"))
    assert_equal(
      ["(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["-(", "~aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["-(", "~aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa -bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      [["(", "aaa", ")"], ["-(", "bbb", ")"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = false,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      [["(", "aaa", ")"], ["(", "bbb", ")"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = false,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      [["aaa"], ["bbb"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = false,
        flatten: flatten = false,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      [["aaa"], "-", ["bbb"]],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = false,
        flatten: flatten = false,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "-", "bbb"],
      TagQuery.scan_recursive(
        "( aaa ) -( bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = false,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["~(", "AAa", "-BBB*", ")", "-bbb*"],
      TagQuery.scan_recursive(
        "~( AAa -BBB* ) -bbb*",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      [["~(", "AAa", "-BBB*", ")"], "-bbb*"],
      TagQuery.scan_recursive(
        "~( AAa -BBB* ) -bbb*",
        strip_duplicates_at_level: strip_duplicates_at_level = false,
        delimit_groups: delimit_groups = true,
        flatten: flatten = false,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    # assert_equal(["~AAa", "-BBB*", "-bbb*"], TagQuery.scan_recursive("~AAa -BBB* -bbb*"))
    assert_equal(
      ["aaa", 'test:"with spaces"', "def"],
      TagQuery.scan_recursive('aaa test:"with spaces" def'),
    )
  end

  # TODO: Figure out tests for normalizing tags in scan_recursive
  # TODO: Figure out tests for sorting tags in scan_recursive
  # TODO: Figure out tests for distributing prefixes in scan_recursive

  should "recursively scan and strip duplicates" do
    assert_equal(
      ["aaa", "-bbb"],
      TagQuery.scan_recursive(
        "aaa aaa aaa -bbb",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        # delimit_groups: delimit_groups = true,
        # flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      # delimit_groups: delimit_groups,
      # flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      %w[aaa bbb],
      TagQuery.scan_recursive(
        "~aaa -aaa ~aaa -bbb",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        # delimit_groups: delimit_groups = true,
        # flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      # delimit_groups: delimit_groups,
      # flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "~aaa", "-aaa", "-bbb"],
      TagQuery.scan_recursive(
        "aaa ~aaa -aaa ~aaa -bbb",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        # delimit_groups: delimit_groups = true,
        # flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      # delimit_groups: delimit_groups,
      # flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "-( ~aaa ~aaa ~aaa -bbb )",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "~aaa -aaa -( ~aaa ~aaa ~aaa -bbb ) ~aaa -aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "(", "aaa", "bbb", ")"],
      TagQuery.scan_recursive(
        "~aaa -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) aaa -aaa ~aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "(", "(", "aaa", "bbb", ")", ")"],
      TagQuery.scan_recursive(
        "~aaa ( -( ~aaa ~aaa ~aaa -bbb ) ( ~aaa ~aaa -bbb -bbb ) ) aaa -aaa ~aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = true,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) aaa -aaa ~aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
    assert_equal(
      ["aaa", "-aaa", "~aaa", "(", "-(", "~aaa", "-aaa", "-bbb", ")", "(", "~aaa", "-aaa", "-bbb", ")", ")"],
      TagQuery.scan_recursive(
        "aaa -aaa ~aaa ( -( ~aaa -aaa ~aaa -bbb ) ( ~aaa -aaa -bbb -bbb ) ( -aaa ~aaa -aaa -bbb ) ) aaa -aaa ~aaa",
        strip_duplicates_at_level: strip_duplicates_at_level = true,
        delimit_groups: delimit_groups = true,
        flatten: flatten = true,
        strip_prefixes: strip_prefixes = false,
      ),
      strip_duplicates_at_level: strip_duplicates_at_level,
      delimit_groups: delimit_groups,
      flatten: flatten,
      strip_prefixes: strip_prefixes,
    )
  end

  should "not strip out valid characters when scanning" do
    assert_equal(%w[aaa bbb], TagQuery.scan("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
    assert_equal(%w[aaa bbb], TagQuery.scan_search("aaa bbb"))
    assert_equal(%w[favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%], TagQuery.scan_search("favgroup:yondemasu_yo,_azazel-san. pool:ichigo_100%"))
  end

  should "parse a query" do
    create(:tag, name: "acb")
    assert_equal(["abc"], TagQuery.new("md5:abc")[:md5])
    assert_equal([[:between, 1, 2]], TagQuery.new("id:1..2")[:post_id])
    assert_equal([[:gt, 2]], TagQuery.new("id:>2")[:post_id])
    assert_equal([[:gte, 2]], TagQuery.new("id:>=2")[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("id:<3")[:post_id])
    assert_equal([[:lte, 3]], TagQuery.new("id:<=3")[:post_id])
    assert_equal([[:lt, 3]], TagQuery.new("ID:<3")[:post_id])
    assert_equal([[:lte, 3]], TagQuery.new("ID:<=3")[:post_id])
    assert_equal(["acb"], TagQuery.new("a*b")[:tags][:should])
    # TODO: Add test case for groups
  end

  should "allow multiple types for a metatag in a single query" do
    query = TagQuery.new("id:1 -id:2 ~id:3 id:4 -id:5 ~id:6")
    assert_equal([[:eq, 1], [:eq, 4]], query[:post_id])
    assert_equal([[:eq, 2], [:eq, 5]], query[:post_id_must_not])
    assert_equal([[:eq, 3], [:eq, 6]], query[:post_id_should])
  end

  should "fail for more than 40 tags" do
    assert_raise(TagQuery::CountExceededError) do
      TagQuery.new("rating:s width:10 height:10 user:bob #{[*'aa'..'zz'].join(' ')}")
    end
  end

  # TODO: Figure out tests for recurse_through_metatags
  # TODO: Figure out tests for normalize
end
