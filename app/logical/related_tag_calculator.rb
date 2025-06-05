# frozen_string_literal: true

class RelatedTagCalculator
  MAX_RESULTS = 25

  #
  # ### Parameters
  # * `tags` {`String`}: The query to sample.
  # * `category_constraint` [`nil`]: The category to limit returned tags to.
  def self.calculate_from_sample_to_array(tags, category_constraint = nil)
    convert_hash_to_array(calculate_from_sample(tags, Danbooru.config.post_sample_size, category_constraint))
  end

  def self.calculate_from_posts_to_array(posts)
    convert_hash_to_array(calculate_from_posts(posts))
  end

  def self.calculate_from_posts(posts)
    counts = Hash.new {|h, k| h[k] = 0}

    posts.flat_map(&:tag_array).each do |tag|
      counts[tag] += 1
    end

    counts
  end

  # Generates a `Hash` of the occurrences of a tag in a sample set of posts matching the given query.
  # ### Parameters
  # * `tags` {`String`}: The query to sample.
  # * `sample_size`: The number of samples to retrieve.
  # * `category_constraint` [`nil`]: The category to limit returned tags to.
  # * `max_results` [`MAX_RESULTS`]: The maximum tags to return.
  # ### Returns
  # A `Hash` w/ all the tags from the sampled posts and values of the number of occurrences of that tag.
  def self.calculate_from_sample(tags, sample_size, category_constraint = nil, max_results = MAX_RESULTS)
    Post.with_timeout(5_000, []) do
      sample = Post.sample(tags, sample_size)
      posts_with_tags = sample.with_unflattened_tags

      if category_constraint
        posts_with_tags = posts_with_tags.joins("JOIN tags ON tags.name = tag").where("tags.category" => category_constraint)
      end

      # IDEA: If this is ordered, then this shouldn't need to be resorted by `convert_hash_to_array`.
      counts = posts_with_tags.order("count_all DESC").limit(max_results).group("tag").count(:all)
      counts
    end
  end

  def self.convert_hash_to_array(hash, limit = MAX_RESULTS)
    hash.to_a.sort_by {|x| [-x[1], x[0]] }.slice(0, limit)
  end

  def self.convert_hash_to_string(hash)
    convert_hash_to_array(hash).flatten.join(" ")
  end
end
