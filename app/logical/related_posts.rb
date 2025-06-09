# frozen_string_literal: true

class RelatedPosts
  # #region Levenshtein Distance
  SYM_MAP = {
    deletion: "-",
    insertion: "+",
    substitution: "%",
    none: "=",
    # transposition: "^",
  }.freeze
  class LdNode
    attr_accessor :index, :operation, :nodes, :value

    def initialize(index, operation, nodes, value = nil)
      # `{ x: Integer, y: Integer }`
      @index = index
      # `Symbol`
      @operation = operation
      # `LdNode[][]`
      @nodes = nodes
      # `String`
      @value = value || nodes[0][y]
    end

    def prior_value
      @prior_value ||= nodes[x][0]
    end

    def update(index: nil, value: nil, operation: nil, nodes: nil)
      @index = index if index
      @value = value if value
      @operation = operation if operation
      @nodes = nodes if nodes
    end

    def x = index.[](:x)
    def y = index.[](:y)

    def siblings
      @siblings ||= if nodes[x][y].is_a?(Array)
                      nodes[x][y] - self
                    else
                      []
                    end
    end

    def siblings_and_self
      @siblings_and_self ||= if nodes[x][y].is_a?(Array)
                               nodes[x][y]
                             else
                               [self]
                             end
    end

    def parent
      @parent ||= case operation
                  when :none, :substitution
                    nodes[x - 1][y - 1]
                  when :insertion
                    nodes[x][y - 1]
                  when :deletion
                    nodes[x - 1][y]
                  else
                    raise "Invalid operation (#{operation})"
                  end
    end

    def source
      nodes[1..].map { |e| e.first.value }.join("|")
    end

    def destination
      nodes[0][1..].map(&:value).join("|")
    end

    def from
      nodes[1..(x - 1)].map { |e| e.first.value }.join("|")
    end

    def to
      nodes[0][1..(y - 1)].map(&:value).join("|")
    end

    def trace_path(tail = [])
      tail.unshift(siblings_and_self.length == 1 ? self : siblings_and_self)
      if x > 1 && y > 1
        if parent.is_a?(Array)
          parent.first
        else
          parent
        end.trace_path(tail)
      end
      tail
    end

    def to_s
      if x >= 1 && y >= 1
        case operation
        when :deletion
          "#{SYM_MAP[operation]}#{prior_value}"
        when :substitution
          "#{SYM_MAP[operation]}#{prior_value}->#{value}"
        when :insertion, :none
          "#{SYM_MAP[operation]}#{value}"
        else
          raise "Invalid operation (#{operation})"
        end
      end
    end
  end

  OPERATION_WEIGHTS = {
    deletion: 1.0,
    insertion: 1.0,
    substitution: 1.0,
    none: 0.0,
    # transposition: 1.0,
  }.freeze

  # The largest possible operation weight in `OPERATION_WEIGHTS`. Used for normalization.
  MAX_WEIGHT = OPERATION_WEIGHTS.values.max

  # Levenshtein distance
  # ### Parameters
  # * `source_arr`: a collection
  # * `dest_arr`: a collection
  # * `normalize` [`true`]: normalize the output
  #
  # These "array" parameters must have these properties:
  # * Have a `[]` accessor accepting a single `Number` index
  # * Contain members that can all be compared with each other with the `==` operator
  # * Respond to `length` w/ a `Numeric`
  #
  # This means everything from proper `Array`s to `String`s can be passed in, and the function will
  # behave correctly; they don't even have to have the same type (though the values within them must
  # be comparable, of course).
  # ### Returns
  # A number representing the number of weighted steps needed to be taken to go from `source_arr` to
  # `dest_arr` (lower score == more similar); if normalized, 0 means inputs are considered identical, 1 means they are  as
  # different as can be.
  #
  # IDEA: Convert to [memory-optimized variant]()
  # IDEA: Add support for [transpositions](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance)?
  # * Unlike typing correction, tag arrays have a proper order. Assuming inputs are ordered
  # correctly, probably shouldn't actually matter.
  # * However, this is generic enough to also be used for spell check, and it would help in that case
  # NOTE: Derived from [here](https://en.wikipedia.org/wiki/Wagner%E2%80%93Fischer_algorithm#:~:text=function%20Distance(,%2C%20n%5D).
  def self.l_distance(source_arr, dest_arr, normalize: true)
    num_rows = source_arr.length
    num_cols = dest_arr.length
    max_weight = if normalize
                   [num_rows, num_cols].max * MAX_WEIGHT
                 else
                   1
                 end
    # #region Debug
    # puts "#{source_arr} (L: #{source_arr.length}) -> #{dest_arr} (L: #{dest_arr.length})"
    # max_tag_length = 1
    # pad_char = ""
    # if [dest_arr, source_arr].all? { |e| e.respond_to?(:inject) }
    #   max_tag_length = dest_arr.inject(source_arr.inject(0) { |p, e| [e.length, p].max }) { |p, e| [e.length, p].max }
    #   pad_char = " "
    # end
    # gen_indicator = ->(prior, str, sym) { "#{sym}#{str}" }
    # #endregion Debug

    # A 2d array sized 1 larger than each input
    d = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| 0 } }
    # d_substring = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| "" } }
    # d_nodes = [*(0..num_rows)].map { |i| [*(0..num_cols)].map { |j| "undefined" } }
    # d_nodes[0][0] = LdNode.new({ x: 0, y: 0 }, :none, d_nodes, "")

    (1..num_rows).each { |i| d[i][0] = i * OPERATION_WEIGHTS[:deletion] }
    # (1..num_rows).each { |i| d_substring[i][0] = source_arr[i - 1] }
    # (1..num_rows).each { |i| d_nodes[i][0] = LdNode.new({ x: i, y: 0 }, :deletion, d_nodes, source_arr[i - 1]) }

    (1..num_cols).each { |j| d[0][j] = j * OPERATION_WEIGHTS[:insertion] }
    # (1..num_cols).each { |j| d_substring[0][j] = dest_arr[j - 1] }
    # (1..num_cols).each { |j| d_nodes[0][j] = LdNode.new({ x: 0, y: j }, :insertion, d_nodes, dest_arr[j - 1]) }

    (1..num_cols).each do |j| # rubocop:disable Style/CombinableLoops -- This is not actually combinable; need to pre-calculate the 1st col
      (1..num_rows).each do |i|
        substitution_cost = source_arr[i - 1] == dest_arr[j - 1] ? 0 : OPERATION_WEIGHTS[:substitution]
        d[i][j] = [
          d[i - 1][j] + OPERATION_WEIGHTS[:deletion],
          d[i][j - 1] + OPERATION_WEIGHTS[:insertion],
          d[i - 1][j - 1] + substitution_cost,
        ].min
        # #region Debug
        # deletion_output = d[i - 1][j] + OPERATION_WEIGHTS[:deletion]
        # insertion_output = d[i][j - 1] + OPERATION_WEIGHTS[:insertion]
        # substitution_output = d[i - 1][j - 1] + substitution_cost
        # if substitution_output == deletion_output
        #   if insertion_output == deletion_output # substitution == deletion == insertion
        #     # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[0][j], "?")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   elsif deletion_output < insertion_output # (substitution == deletion) < insertion
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[0][j], "-%")}"
        #     d_nodes[i][j] = [
        #       # LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < (deletion == substitution)
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # elsif substitution_output < deletion_output
        #   if substitution_output < insertion_output # substitution < |insertion deletion|
        #     if substitution_output == 0
        #       # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[i][0], "=")}"
        #       d_nodes[i][j] = LdNode.new({ x: i, y: j }, :none, d_nodes)
        #     else
        #       # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[0][j], "%")}"
        #       d_nodes[i][j] = LdNode.new({ x: i, y: j }, :substitution, d_nodes)
        #     end
        #   elsif substitution_output == insertion_output # (insertion == substitution) < deletion
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+%")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       # LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < substitution < deletion
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # elsif deletion_output < substitution_output
        #   if deletion_output < insertion_output # deletion < |insertion substitution|
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[i][0], "-")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :deletion, d_nodes)
        #   elsif deletion_output == insertion_output # (insertion == deletion) < substitution
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[i][0], "+-")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       # LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < deletion < substitution
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # end
        # #endregion Debug
      end
    end
    # d.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%4s", e1) }}" }
    # d_substring.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }}" }
    # d_substring.each { |e| puts e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }.join("|") }
    # d_substring.each { |e| puts e.inject("") { |p, e1| p += Kernel.sprintf("%#{max_tag_length}s|", e1) } }
    #
    # dbg_out = [*(0..num_cols)]
    # for i in 1..num_rows do
    #   dbg_out[0] = d_substring[i][0]
    # end
    # for j in 1..num_cols do
    #   for i in 1..num_rows do
    #     dbg_out[j] = "#{dbg_out[j]},#{d_substring[i][j]}"
    #   end
    # end
    # d_substring[0][0] = "_"
    # puts "echo #{dbg_out.join(",")} | column -t --table-columns #{d_substring[0].join(",")} -s , -W #{d_substring[0].join(",")}"
    #

    # d_substring.each { |e| puts e.map { |e1| Kernel.sprintf("%#{max_tag_length + 2 + 6}s", e1) }.join("|") }

    # d_nodes[num_rows][num_cols]

    # puts "Result: #{sprintf("%0 4.2f", d[num_rows][num_cols])} / #{sprintf("%0 4.2f", max_weight)} = #{d[num_rows][num_cols] / max_weight}"
    d[num_rows][num_cols] / max_weight
  end

  # Damerau–Levenshtein distance
  # ### Parameters
  # * `source_arr`: a collection
  # * `dest_arr`: a collection
  # * `normalize` [`true`]: normalize the output
  #
  # These "array" parameters must have these properties:
  # * Have a `[]` accessor accepting a single `Number` index
  # * Contain members that can all be compared with each other with the `==` operator
  # * Respond to `length` w/ a `Numeric`
  #
  # This means everything from proper `Array`s to `String`s can be passed in, and the function will
  # behave correctly; they don't even have to have the same type (though the values within them must
  # be comparable, of course).
  # ### Returns
  # A number representing the number of weighted steps needed to be taken to go from `source_arr` to
  # `dest_arr` (lower score == more similar); if normalized, 0 means inputs are considered identical, 1 means they are  as
  # different as can be.
  #
  # IDEA: Convert to [memory-optimized variant]()
  # IDEA: Add support for [transpositions](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance)?
  # * Unlike typing correction, tag arrays have a proper order. Assuming inputs are ordered
  # correctly, probably shouldn't actually matter.
  # * However, this is generic enough to also be used for spell check, and it would help in that case
  # NOTE: Derived from [here](https://en.wikipedia.org/wiki/Wagner%E2%80%93Fischer_algorithm#:~:text=function%20Distance(,%2C%20n%5D).
  def self.dl_distance(source_arr, dest_arr, normalize: true)
    num_rows = source_arr.length
    num_cols = dest_arr.length
    max_weight = if normalize
                   [num_rows, num_cols].max * MAX_WEIGHT
                 else
                   1
                 end
    # #region Debug
    # puts "#{source_arr} (L: #{source_arr.length}) -> #{dest_arr} (L: #{dest_arr.length})"
    # max_tag_length = 1
    # pad_char = ""
    # if [dest_arr, source_arr].all? { |e| e.respond_to?(:inject) }
    #   max_tag_length = dest_arr.inject(source_arr.inject(0) { |p, e| [e.length, p].max }) { |p, e| [e.length, p].max }
    #   pad_char = " "
    # end
    # gen_indicator = ->(prior, str, sym) { "#{sym}#{str}" }
    # #endregion Debug

    # A 2d array sized 1 larger than each input
    d = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| 0 } }
    # d_substring = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| "" } }
    # d_nodes = [*(0..num_rows)].map { |i| [*(0..num_cols)].map { |j| "undefined" } }
    # d_nodes[0][0] = LdNode.new({ x: 0, y: 0 }, :none, d_nodes, "")

    (1..num_rows).each { |i| d[i][0] = i * OPERATION_WEIGHTS[:deletion] }
    # (1..num_rows).each { |i| d_substring[i][0] = source_arr[i - 1] }
    # (1..num_rows).each { |i| d_nodes[i][0] = LdNode.new({ x: i, y: 0 }, :deletion, d_nodes, source_arr[i - 1]) }

    (1..num_cols).each { |j| d[0][j] = j * OPERATION_WEIGHTS[:insertion] }
    # (1..num_cols).each { |j| d_substring[0][j] = dest_arr[j - 1] }
    # (1..num_cols).each { |j| d_nodes[0][j] = LdNode.new({ x: 0, y: j }, :insertion, d_nodes, dest_arr[j - 1]) }

    (1..num_cols).each do |j| # rubocop:disable Style/CombinableLoops -- This is not actually combinable; need to pre-calculate the 1st col
      (1..num_rows).each do |i|
        is_same = source_arr[i - 1] == dest_arr[j - 1]
        substitution_cost = is_same ? 0 : OPERATION_WEIGHTS[:substitution]
        d[i][j] = [
          d[i - 1][j] + OPERATION_WEIGHTS[:deletion],
          d[i][j - 1] + OPERATION_WEIGHTS[:insertion],
          d[i - 1][j - 1] + substitution_cost,
        ].min
        if !is_same && i > 2 && j > 2 && source_arr[i - 1] == dest_arr[j - 2] && source_arr[i - 2] == dest_arr[j - 1]
          d[i, j] = [d[i, j], d[i - 2, j - 2] + OPERATION_WEIGHTS[:transposition]].min
        end
        # #region Debug
        # deletion_output = d[i - 1][j] + OPERATION_WEIGHTS[:deletion]
        # insertion_output = d[i][j - 1] + OPERATION_WEIGHTS[:insertion]
        # substitution_output = d[i - 1][j - 1] + substitution_cost
        # if substitution_output == deletion_output
        #   if insertion_output == deletion_output # substitution == deletion == insertion
        #     # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[0][j], "?")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   elsif deletion_output < insertion_output # (substitution == deletion) < insertion
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[0][j], "-%")}"
        #     d_nodes[i][j] = [
        #       # LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < (deletion == substitution)
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # elsif substitution_output < deletion_output
        #   if substitution_output < insertion_output # substitution < |insertion deletion|
        #     if substitution_output == 0
        #       # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[i][0], "=")}"
        #       d_nodes[i][j] = LdNode.new({ x: i, y: j }, :none, d_nodes)
        #     else
        #       # d_substring[i][j] = "#{i - 1},#{j - 1} #{gen_indicator.call(d_substring[i - 1][j - 1], d_substring[0][j], "%")}"
        #       d_nodes[i][j] = LdNode.new({ x: i, y: j }, :substitution, d_nodes)
        #     end
        #   elsif substitution_output == insertion_output # (insertion == substitution) < deletion
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+%")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       # LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < substitution < deletion
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # elsif deletion_output < substitution_output
        #   if deletion_output < insertion_output # deletion < |insertion substitution|
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[i][0], "-")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :deletion, d_nodes)
        #   elsif deletion_output == insertion_output # (insertion == deletion) < substitution
        #     # d_substring[i][j] = "#{i - 1},#{j} #{gen_indicator.call(d_substring[i - 1][j], d_substring[i][0], "+-")}"
        #     d_nodes[i][j] = [
        #       LdNode.new({ x: i, y: j }, :insertion, d_nodes),
        #       LdNode.new({ x: i, y: j }, :deletion, d_nodes),
        #       # LdNode.new({ x: i, y: j }, :substitution, d_nodes),
        #     ]
        #   else # insertion < deletion < substitution
        #     # d_substring[i][j] = "#{i},#{j - 1} #{gen_indicator.call(d_substring[i][j - 1], d_substring[0][j], "+")}"
        #     d_nodes[i][j] = LdNode.new({ x: i, y: j }, :insertion, d_nodes)
        #   end
        # end
        # #endregion Debug
      end
    end
    # d.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%4s", e1) }}" }
    # d_substring.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }}" }
    # d_substring.each { |e| puts e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }.join("|") }
    # d_substring.each { |e| puts e.inject("") { |p, e1| p += Kernel.sprintf("%#{max_tag_length}s|", e1) } }
    #
    # dbg_out = [*(0..num_cols)]
    # for i in 1..num_rows do
    #   dbg_out[0] = d_substring[i][0]
    # end
    # for j in 1..num_cols do
    #   for i in 1..num_rows do
    #     dbg_out[j] = "#{dbg_out[j]},#{d_substring[i][j]}"
    #   end
    # end
    # d_substring[0][0] = "_"
    # puts "echo #{dbg_out.join(",")} | column -t --table-columns #{d_substring[0].join(",")} -s , -W #{d_substring[0].join(",")}"
    #

    # d_substring.each { |e| puts e.map { |e1| Kernel.sprintf("%#{max_tag_length + 2 + 6}s", e1) }.join("|") }

    # d_nodes[num_rows][num_cols]

    # puts "Result: #{sprintf("%0 4.2f", d[num_rows][num_cols])} / #{sprintf("%0 4.2f", max_weight)} = #{d[num_rows][num_cols] / max_weight}"
    d[num_rows][num_cols] / max_weight
  end
  # #endregion Levenshtein Distance

  def self.max_results
    CurrentUser.user&.per_page || Danbooru.config.records_per_page
  end

  # TODO: Make stubs private

  # #region Stubs

  # TODO: Use `max_results`?
  def self.calculate_stub(posts_array, tag_array, _max_results)
    posts_array.index_with { |e| RelatedPosts.l_distance(tag_array, e.tag_string.split) }
  end

  def self.get_stub(posts_array, tag_array, max_results)
    posts_array.sort_by { |e| RelatedPosts.l_distance(tag_array, e.tag_string.split) }.first(max_results)
  end

  # IDEA: Stop relying on auto-conversion to array & properly handle relation
  def self.from_tags_and_relation(tag_array, relation, query = "", max_results: RelatedPosts.max_results, &)
    relation = PostQueryBuilder.query_relation(query, relation) if query.present?
    return if relation.empty?
    if relation.first.is_a?(Post)
      yield(relation, tag_array, max_results)
    end
  end

  # TODO: Use `_query`?
  def self.from_tags_and_array(tag_array, posts, _query = "", max_results: RelatedPosts.max_results, &)
    return if posts.empty?
    if posts.first.is_a?(Post)
      yield(posts, tag_array, max_results)
    end
  end

  def self.from_tags_and_collection(tag_array, posts, query = "", max_results: RelatedPosts.max_results, &)
    if posts.is_a?(ActiveRecord::Relation)
      from_tags_and_relation(tag_array, posts, query, max_results, &)
    elsif posts.is_a?(Array)
      from_tags_and_array(tag_array, posts, query, max_results, &)
    end
  end

  # IDEA: Stop relying on auto-conversion to array & properly handle relation
  def self.from_post_and_relation(post, relation, query = "", max_results: RelatedPosts.max_results, &)
    relation = relation.excluding(post) # Remove given post from results
    relation = PostQueryBuilder.query_relation(query, relation) if query.present?
    return if relation.empty?
    if relation.first.is_a?(Post)
      yield(relation, post.tag_string.split.freeze, max_results)
    end
  end

  # TODO: Use `_query`?
  # NOTE: Has a safety to prevent post deletion if incorrectly given a Relation or something.
  def self.from_post_and_array(post, posts, _query = "", max_results: RelatedPosts.max_results, &)
    posts.delete(post) unless posts.respond_to?(:destroy) # Remove given post from results
    return if posts.empty?
    if posts.first.is_a?(Post)
      yield(posts, post.tag_string.split.freeze, max_results)
    end
  end

  def self.from_post_and_collection(post, posts, query = "", max_results: RelatedPosts.max_results, &)
    if posts.is_a?(ActiveRecord::Relation)
      from_post_and_relation(post, posts, query, max_results, &)
    elsif posts.is_a?(Array)
      from_post_and_array(post, posts, query, max_results, &)
    end
  end
  # #endregion Stubs

  # #region "Public" Methods
  def self.get_from_tags_and_collection(tag_array, posts, query = "", max_results: RelatedPosts.max_results)
    RelatedPosts.from_tags_and_collection(tag_array, posts, query, max_results, &method(:get_stub))
  end

  def self.calculate_from_tags_and_collection(tag_array, posts, query = "", max_results: RelatedPosts.max_results)
    RelatedPosts.from_tags_and_collection(tag_array, posts, query, max_results, &method(:calculate_stub))
  end

  def self.get_from_post_and_collection(post, posts, query = "", max_results: RelatedPosts.max_results)
    RelatedPosts.from_post_and_collection(post, posts, query, max_results, &method(:get_stub))
  end

  def self.calculate_from_post_and_collection(post, posts, query = "", max_results: (CurrentUser.user || Danbooru.config.per_page).per_page)
    RelatedPosts.from_post_and_collection(post, posts, query, max_results, &method(:calculate_stub))
  end

  def self.get_from_tags_and_sample(tag_array, query = "", sample_size: Danbooru.config.post_sample_size, max_results: RelatedPosts.max_results)
    RelatedPosts.from_tags_and_relation(tag_array, Post.sample(query, sample_size), max_results: max_results, &method(:get_stub))
  end

  def self.calculate_from_tags_and_sample(tag_array, query = "", sample_size: Danbooru.config.post_sample_size, max_results: RelatedPosts.max_results)
    RelatedPosts.from_tags_and_relation(tag_array, Post.sample(query, sample_size), max_results: max_results, &method(:calculate_stub))
  end

  def self.get_from_post_and_sample(post, query = "", sample_size: Danbooru.config.post_sample_size, max_results: RelatedPosts.max_results)
    RelatedPosts.from_post_and_relation(post, Post.sample(query, sample_size), max_results: max_results, &method(:get_stub))
  end

  def self.calculate_from_post_and_sample(post, query = "", sample_size: Danbooru.config.post_sample_size, max_results: RelatedPosts.max_results)
    RelatedPosts.from_post_and_relation(post, Post.sample(query, sample_size), max_results: max_results, &method(:calculate_stub))
  end
  # #endregion "Public" Methods

  def self.invert_hash(hash, ordered: false)
    pmi = {}
    hash.each_pair do |p, d|
      if pmi.key?(d)
        if pmi[d].is_a?(Array)
          pmi[d] << p
        else
          pmi[d] = [pmi[d], p]
        end
      else
        pmi[d] = p
      end
    end
    return pmi unless ordered
    ret = {}
    pmi.keys.sort.each do |d|
      ret[d] = pmi[d]
    end
    ret
  end

  def self.hash_to_sorted_array(hash)
    posts = []
    pmi = RelatedPosts.invert_hash(hash)
    pmi.keys.sort.each do |d|
      if pmi[d].is_a?(Array)
        posts.push(*pmi[d])
      else
        posts.push(pmi[d])
      end
    end
    posts
  end
end
