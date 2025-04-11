# frozen_string_literal: true

class ElasticPostQueryBuilder < ElasticQueryBuilder
  LOCK_TYPE_TO_INDEX_FIELD = {
    rating: :rating_locked,
    note: :note_locked,
    status: :status_locked,
  }.freeze

  # Used to determine if a grouped search that wouldn't automatically filter out deleted searches
  # will force other grouped searches to not automatically filter out deleted searches. (i.e. if the
  # `-status:deleted` filter is toggled off globally or only on descendants & ancestors).
  GLOBAL_DELETED_FILTER = true

  ERROR_ON_DEPTH_EXCEEDED = true

  def initialize( # rubocop:disable Metrics/ParameterLists
    query,
    resolve_aliases:,
    free_tags_count:,
    enable_safe_mode:,
    always_show_deleted:,
    **kwargs
  )
    @depth = kwargs.fetch(:depth, 0)
    # If it got this far, failing silently didn't work; force error
    raise TagQuery::DepthExceededError if @depth >= TagQuery::DEPTH_LIMIT
    unless query.is_a?(TagQuery)
      # Rails.logger.debug { -"Query: #{query}" }
      query = TagQuery.new(
        query,
        resolve_aliases: resolve_aliases,
        free_tags_count: free_tags_count,
        **kwargs,
        can_have_groups: true,
      )
    end
    # Rails.logger.debug { -"TQ.q: #{query.q}" }
    # Rails.logger.debug { -"TQ#hide_deleted_posts?: #{query.hide_deleted_posts?(at_any_level: true)}" }
    @resolve_aliases = resolve_aliases
    @free_tags_count = free_tags_count
    @enable_safe_mode = enable_safe_mode
    # Rails.logger.debug { -"asd: #{always_show_deleted}" }
    @always_show_deleted = always_show_deleted
    # Rails.logger.debug { -"Check?: #{GLOBAL_DELETED_FILTER && @depth <= 0}" }
    @always_show_deleted ||= !query.hide_deleted_posts?(at_any_level: true) if GLOBAL_DELETED_FILTER && @depth <= 0
    # Rails.logger.debug { -"@always_show_deleted: #{@always_show_deleted}" }
    @error_on_depth_exceeded = kwargs.fetch(:error_on_depth_exceeded, ERROR_ON_DEPTH_EXCEEDED)
    super(query)
  end

  def model_class
    Post
  end

  def add_tag_string_search_relation(tags)
    must.concat(tags[:must].map { |x| { term: { tags: x } } })
    must_not.concat(tags[:must_not].map { |x| { term: { tags: x } } })
    should.concat(tags[:should].map { |x| { term: { tags: x } } })
  end

  # Adds the grouped subsearches to the query.
  #
  # NOTE: Has the hidden side-effect of updating `always_show_deleted` with each subsearches'
  # `hide_deleted_posts?` at each step in the chain.
  def add_group_search_relation(groups)
    raise TagQuery::DepthExceededError if (@depth + 1) >= TagQuery::DEPTH_LIMIT && @error_on_depth_exceeded
    return if (@depth + 1) >= TagQuery::DEPTH_LIMIT || groups.blank? || (groups[:must].blank? && groups[:must_not].blank? && groups[:should].blank?)
    asd_cache = @always_show_deleted
    cb = ->(x) do
      # If we aren't using a global filter and we haven't already disabled `-status:deleted`
      # auto-insertion, then downstream queries need to be either pre-parsed or analyzed with
      # `should_hide_deleted?` to determine if parents should hide deleted for their children.
      unless GLOBAL_DELETED_FILTER || asd_cache || x.is_a?(TagQuery)
        x = TagQuery.new(
          x,
          resolve_aliases: @resolve_aliases,
          free_tags_count: @free_tags_count + @q.tag_count,
          error_on_depth_exceeded: @error_on_depth_exceeded,
          depth: @depth + 1,
          hoisted_metatags: nil,
          process_groups: true,
        )
      end
      temp = ElasticPostQueryBuilder.new(
        x,
        resolve_aliases: @resolve_aliases,
        free_tags_count: @free_tags_count + @q.tag_count,
        enable_safe_mode: @enable_safe_mode,
        always_show_deleted: GLOBAL_DELETED_FILTER ? true : asd_cache,
        error_on_depth_exceeded: @error_on_depth_exceeded,
        depth: @depth + 1,
        hoisted_metatags: nil,
      )
      @always_show_deleted ||= !temp.innate_hide_deleted_posts? unless GLOBAL_DELETED_FILTER
      temp.create_query_obj(return_nil_if_empty: false)
    end
    must.concat(groups[:must].map(&cb).compact) if groups[:must].present?
    must_not.concat(groups[:must_not].map(&cb).compact) if groups[:must_not].present?
    should.concat(groups[:should].map(&cb).compact) if groups[:should].present?
  end

  def hide_deleted_posts?(at_any_level: !GLOBAL_DELETED_FILTER)
    !(@always_show_deleted || q[:show_deleted] || !q.hide_deleted_posts?(at_any_level: at_any_level))
  end

  def innate_hide_deleted_posts?(at_any_level: !GLOBAL_DELETED_FILTER)
    !(q[:show_deleted] || !q.hide_deleted_posts?(at_any_level: at_any_level))
  end

  def build
    if @enable_safe_mode
      must.push({term: {rating: "s"}})
    end

    add_array_range_relation(:post_id, :id)
    add_array_range_relation(:mpixels, :mpixels)
    add_array_range_relation(:ratio, :aspect_ratio)
    add_array_range_relation(:width, :width)
    add_array_range_relation(:height, :height)
    add_array_range_relation(:duration, :duration)
    add_array_range_relation(:score, :score)
    add_array_range_relation(:fav_count, :fav_count)
    add_array_range_relation(:filesize, :file_size)
    add_array_range_relation(:change_seq, :change_seq)
    add_array_range_relation(:date, :created_at)
    add_array_range_relation(:age, :created_at)

    TagCategory::CATEGORIES.each do |category|
      add_array_range_relation(:"#{category}_tag_count", "tag_count_#{category}")
    end

    add_array_range_relation(:post_tag_count, :tag_count)

    TagQuery::COUNT_METATAGS.map(&:to_sym).each do |column|
      if q[column]
        relation = range_relation(q[column], column)
        must.push(relation) if relation
      end
    end

    if q[:md5]
      must.push(match_any(*(q[:md5].map { |m| { term: { md5: m } } })))
    end

    if q[:status] == "pending"
      must.push({term: {pending: true}})
    elsif q[:status] == "flagged"
      must.push({term: {flagged: true}})
    elsif q[:status] == "modqueue"
      must.push(match_any({ term: { pending: true } }, { term: { flagged: true } }))
    elsif q[:status] == "deleted"
      must.push({term: {deleted: true}})
    elsif q[:status] == "active"
      must.concat([{term: {pending: false}},
                   {term: {deleted: false}},
                   {term: {flagged: false}}])
    elsif q[:status] == "all" || q[:status] == "any"
      # do nothing
    elsif q[:status_must_not] == "pending"
      must_not.push({term: {pending: true}})
    elsif q[:status_must_not] == "flagged"
      must_not.push({term: {flagged: true}})
    elsif q[:status_must_not] == "modqueue"
      must_not.push(match_any({ term: { pending: true } }, { term: { flagged: true } }))
    elsif q[:status_must_not] == "deleted"
      must_not.push({term: {deleted: true}})
    elsif q[:status_must_not] == "active"
      must.push(match_any({ term: { pending: true } }, { term: { deleted: true } }, { term: { flagged: true } }))
    end

    add_array_relation(:uploader_ids, :uploader)
    add_array_relation(:approver_ids, :approver, any_none_key: :approver)
    add_array_relation(:commenter_ids, :commenters, any_none_key: :commenter)
    add_array_relation(:noter_ids, :noters, any_none_key: :noter)
    add_array_relation(:note_updater_ids, :noters) # Broken, index field missing
    add_array_relation(:pool_ids, :pools, any_none_key: :pool)
    add_array_relation(:set_ids, :sets)
    add_array_relation(:fav_ids, :faves)
    add_array_relation(:parent_ids, :parent, any_none_key: :parent)

    add_array_relation(:rating, :rating)
    add_array_relation(:filetype, :file_ext)
    add_array_relation(:delreason, :del_reason, action: :wildcard)
    add_array_relation(:description, :description, action: :match_phrase_prefix)
    add_array_relation(:note, :notes, action: :match_phrase_prefix)
    add_array_relation(:sources, :source, any_none_key: :source, action: :wildcard)
    add_array_relation(:deleter, :deleter)
    add_array_relation(:upvote, :upvotes)
    add_array_relation(:downvote, :downvotes)

    q[:voted]&.each do |voter_id|
      must.push(match_any({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } }))
    end

    q[:voted_must_not]&.each do |voter_id|
      must_not.push({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } })
    end

    q[:voted_should]&.each do |voter_id|
      should.push({ term: { upvotes: voter_id } }, { term: { downvotes: voter_id } })
    end

    if q[:child] == "none"
      must.push({term: {has_children: false}})
    elsif q[:child] == "any"
      must.push({term: {has_children: true}})
    end

    q[:locked]&.each do |lock_type|
      must.push({ term: { LOCK_TYPE_TO_INDEX_FIELD.fetch(lock_type, "missing") => true } })
    end

    q[:locked_must_not]&.each do |lock_type|
      must.push({ term: { LOCK_TYPE_TO_INDEX_FIELD.fetch(lock_type, "missing") => false } })
    end

    q[:locked_should]&.each do |lock_type|
      should.push({ term: { LOCK_TYPE_TO_INDEX_FIELD.fetch(lock_type, "missing") => true } })
    end

    if q.include?(:hassource)
      (q[:hassource] ? must : must_not).push({exists: {field: :source}})
    end

    if q.include?(:hasdescription)
      (q[:hasdescription] ? must : must_not).push({exists: {field: :description}})
    end

    if q.include?(:ischild)
      (q[:ischild] ? must : must_not).push({exists: {field: :parent}})
    end

    if q.include?(:isparent)
      must.push({term: {has_children: q[:isparent]}})
    end

    if q.include?(:inpool)
      (q[:inpool] ? must : must_not).push({exists: {field: :pools}})
    end

    if q.include?(:pending_replacements)
      must.push({term: {has_pending_replacements: q[:pending_replacements]}})
    end

    if q.include?(:artverified)
      must.push({ term: { artverified: q[:artverified] } })
    end

    add_tag_string_search_relation(q[:tags])

    # Update always_show_deleted
    @always_show_deleted ||= q[:show_deleted] unless GLOBAL_DELETED_FILTER

    # Use the updated value in groups
    add_group_search_relation(q[:groups])

    # The groups updated our value; now optionally hide deleted
    # must.push({ term: { deleted: false } }) unless @always_show_deleted
    must.push({ term: { deleted: false } }) if hide_deleted_posts?

    case q[:order]
    when "id", "id_asc"
      order.push({id: :asc})

    when "id_desc"
      order.push({id: :desc})

    when "change", "change_desc"
      order.push({change_seq: :desc})

    when "change_asc"
      order.push({change_seq: :asc})

    when "md5"
      order.push({md5: :desc})

    when "md5_asc"
      order.push({md5: :asc})

    when "score", "score_desc"
      order.concat([{score: :desc}, {id: :desc}])

    when "score_asc"
      order.concat([{score: :asc}, {id: :asc}])

    when "duration", "duration_desc"
      order.concat([{duration: :desc}, {id: :desc}])

    when "duration_asc"
      order.concat([{duration: :asc}, {id: :asc}])

    when "favcount"
      order.concat([{fav_count: :desc}, {id: :desc}])

    when "favcount_asc"
      order.concat([{fav_count: :asc}, {id: :asc}])

    when "created_at", "created_at_desc"
      order.push({created_at: :desc})

    when "created_at_asc"
      order.push({created_at: :asc})

    when "updated", "updated_desc"
      order.concat([{updated_at: :desc}, {id: :desc}])

    when "updated_asc"
      order.concat([{updated_at: :asc}, {id: :asc}])

    when "comment", "comm"
      order.push({commented_at: {order: :desc, missing: :_last}})
      order.push({id: :desc})

    when "comment_bumped"
      must.push({exists: {field: 'comment_bumped_at'}})
      order.push({comment_bumped_at: {order: :desc, missing: :_last}})
      order.push({id: :desc})

    when "comment_bumped_asc"
      must.push({exists: {field: 'comment_bumped_at'}})
      order.push({comment_bumped_at: {order: :asc, missing: :_last}})
      order.push({id: :desc})

    when "comment_asc", "comm_asc"
      order.push({commented_at: {order: :asc, missing: :_last}})
      order.push({id: :asc})

    when "note"
      order.push({noted_at: {order: :desc, missing: :_last}})

    when "note_asc"
      order.push({noted_at: {order: :asc, missing: :_first}})

    when "mpixels", "mpixels_desc"
      order.push({mpixels: :desc})

    when "mpixels_asc"
      order.push({mpixels: :asc})

    when "portrait"
      order.push({aspect_ratio: :asc})

    when "landscape"
      order.push({aspect_ratio: :desc})

    when "filesize", "filesize_desc"
      order.push({file_size: :desc})

    when "filesize_asc"
      order.push({file_size: :asc})

    when /\A(?<column>#{TagQuery::COUNT_METATAGS.join('|')})(_(?<direction>asc|desc))?\z/i
      column = Regexp.last_match[:column]
      direction = Regexp.last_match[:direction] || "desc"
      order.concat([{column => direction}, {id: direction}])

    when "tagcount", "tagcount_desc"
      order.push({tag_count: :desc})

    when "tagcount_asc"
      order.push({tag_count: :asc})

    when /(#{TagCategory::SHORT_NAME_REGEX})tags(?:\Z|_desc)/
      order.push({"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :desc})

    when /(#{TagCategory::SHORT_NAME_REGEX})tags_asc/
      order.push({"tag_count_#{TagCategory::SHORT_NAME_MAPPING[$1]}" => :asc})

    when "rank"
      @function_score = {
        script_score: {
          script: {
            params: { log3: Math.log(3), date2005_05_24: 1_116_936_000 },
            source: "Math.log(doc['score'].value) / params.log3 + (doc['created_at'].value.millis / 1000 - params.date2005_05_24) / 35000",
          },
        },
      }
      must.push({ range: { score: { gt: 0 } } })
      must.push({ range: { created_at: { gte: 2.days.ago } } })
      order.push({ _score: :desc })

    when "random"
      if q[:random_seed].present?
        @function_score = {
          random_score: { seed: q[:random_seed], field: "id" },
          boost_mode: :replace,
        }
      else
        @function_score = {
          random_score: {},
          boost_mode: :replace,
        }
      end

      order.push({_score: :desc})

    else
      order.push({id: :desc})
    end

    if !CurrentUser.user.nil? && !CurrentUser.user.is_staff? && Security::Lockdown.hide_pending_posts_for > 0
      should = [
        {
          range: {
            created_at: {
              lte: Security::Lockdown.hide_pending_posts_for.hours.ago,
            },
          },
        },
        {
          term: {
            pending: false,
          },
        }
      ]

      unless CurrentUser.user.id.nil?
        should.push({
          term: {
            uploader: CurrentUser.user.id,
          },
        })
      end

      must.push({
        bool: {
          should: should,
          minimum_should_match: 1,
        },
      })
    end
    # result = { bool: { must: must.presence || [{ match_all: {} }] } }
    # result[:bool][:must_not] = must_not if must_not.present?
    # result[:bool][:should] = self.should if self.should.present?
    # Rails.logger.debug { "EPQB#B: #{result}" }
  end
end
