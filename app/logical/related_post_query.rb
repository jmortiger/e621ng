# frozen_string_literal: true

class RelatedPostQuery
  include ActiveModel::Serializers::JSON

  attr_reader :id, :query

  def initialize(id: nil, query: nil, post: nil)
    @id = id
    @query = TagQuery.normalize(query)
    @post = post
  end

  def post
    @post ||= id ? Post.find(id) : nil
  end

  def post_for_html
    PostsDecorator.new(post) if post
  end

  def posts_map
    @posts_map ||= if post
                     RelatedPosts.calculate_from_post_and_sample(post, query)
                   else
                     {}
                   end
  end

  def posts_map_id
    @posts_map_id ||= posts_map.transform_keys(&:id)
  end

  def posts_map_sorted
    @posts_map_sorted ||= RelatedPosts.invert_hash(posts_map, ordered: true)
  end

  def posts
    # @posts ||= if @post ||= @id ? Post.find(id) : nil
    #              RelatedPosts.get_from_post_and_sample(post, query)
    #            else
    #              []
    #            end
    @posts ||= RelatedPosts.hash_to_sorted_array(posts_map)
  end

  def posts_for_html
    puts posts.map(&:id).join(" ")
    # PostsDecorator.decorate_collection(posts.paginate_posts)
    PostsDecorator.decorate_collection(Post.where(id: posts.map(&:id)))
    # PostsDecorator.decorate_collection(Post.where(id: posts.map(&:id)).paginate_posts(1))
    # PostsDecorator.decorate_collection(posts)
    # PostsDecorator.decorate_collection(posts, { num_map: @posts_map })
    # PostsDecorator.decorate_collection(posts: posts)
    # @posts.map { |e| PostsDecorator.new(post: e) }
  end

  def serializable_hash(*)
    # posts
    puts(posts_map_sorted.transform_values { |v| v.is_a?(Array) ? v.map(&:id) : v.id })
    posts_map_sorted
  end

  # IDEA: Mimic caching?
end
