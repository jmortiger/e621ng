# frozen_string_literal: true

class RelatedPosts
  OPERATION_WEIGHTS = {
    deletion: 1,
    insertion: 1,
    substitution: 1,
  }.freeze
  # The largest possible operation weight in `OPERATION_WEIGHTS`. Used for normalization.
  MAX_WEIGHT = OPERATION_WEIGHTS.values.inject { |acc, e| [e, acc].max }
  # Levenshtein distance
  # ### Parameters
  # * `source_arr`: a collection
  # * `dest_arr`: a collection
  # * `normalize` [`true`]: normalize the output
  #
  # These array parameters must have 2 properties:
  # * Have a `[]` accessor accepting a single `Number` index
  # * Contain members that can all be compared with each other with the `==` operator
  # ### Returns
  # A number representing the number of weighted steps needed to be taken to go from `source_arr` to
  # `dest_arr` (lower score == more similar); if normalized, 0 means inputs are considered identical, 1 means they are  as
  # different as can be.
  #
  # IDEA: Add support for [transpositions](https://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance)?
  # * Unlike typing correction, tag arrays have a proper order. Assuming inputs are ordered
  # correctly, probably shouldn't actually matter.
  # * However, this is generic enough to also be used for spell check, and it would help in that
  # case
  # NOTE: Derived from [here](https://en.wikipedia.org/wiki/Wagner%E2%80%93Fischer_algorithm#:~:text=function%20Distance(,%2C%20n%5D).
  def self.l_distance(source_arr, dest_arr, normalize: true)
    num_rows = source_arr.length
    num_cols = dest_arr.length
    max_weight = if normalize
                   [num_rows, num_cols].max * MAX_WEIGHT
                 else
                   1
                 end
    # A 2d array sized 1 larger than each input
    d = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| 0 } }
    # d_substring = [*(0..num_rows)].map { |_| [*(0..num_cols)].map { |_| "" } }

    (1..num_rows).each { |i| d[i][0] = i * OPERATION_WEIGHTS[:deletion] }
    # (1..num_rows).each { |i| d_substring[i][0] = source_arr[i - 1] }

    (1..num_cols).each { |j| d[0][j] = j * OPERATION_WEIGHTS[:insertion] }
    # (1..num_cols).each { |j| d_substring[0][j] = dest_arr[j - 1] }

    (1..num_cols).each do |j| # rubocop:disable Style/CombinableLoops -- This is not actually combinable; need to pre-calculate the 1st col
      (1..num_rows).each do |i|
        substitution_cost = source_arr[i - 1] == dest_arr[j - 1] ? 0 : OPERATION_WEIGHTS[:substitution]
        d[i][j] = [
          d[i - 1][j] + OPERATION_WEIGHTS[:deletion],
          d[i][j - 1] + OPERATION_WEIGHTS[:insertion],
          d[i - 1][j - 1] + substitution_cost,
        ].min
      end
    end
    # d.each { |e| puts "#{e}" }
    # max_tag_length = dest_arr.inject(source_arr.inject(0) { |acc, e| [e.length, acc].max }) { |acc, e| [e.length, acc].max }
    # d_substring.each { |e| puts "#{e.map { |e1| Kernel.sprintf("%#{max_tag_length}s", e1) }}" }
    d[num_rows][num_cols] / max_weight
  end
end
