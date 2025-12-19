# frozen_string_literal: true

class TakedownStatsUpdater
  # #region metric formatters
  # A formatter for `TakedownStatsUpdater.metrics`that handles `ActiveSupport::Duration`s.
  # ### Parameters
  # * `duration`
  # * `symbol`
  # ### Returns
  # A properly formatted `String`.
  def self.duration_formatter(duration, symbol = nil)
    case symbol
    when :count
      "#{duration} record(s)"
    else
      "#{duration.respond_to?(:in_days) ? duration.in_days : duration} day(s)"
    end
  end

  # A formatter for `TakedownStatsUpdater.metrics`that handles true/false metrics.
  # ### Parameters
  # * `numeric`
  # * `symbol`
  # ### Returns
  # A properly formatted `String`.
  def self.flag_percent_formatter(numeric, symbol = nil)
    case symbol
    when :sum
      "#{numeric.to_int} instances"
    when :median, :minimum, :maximum
      [false, 0].include?(numeric) ? "false" : "true"
    when :mean, :standard_deviation
      "#{numeric * 100}%"
    when :count
      "#{numeric} record(s)"
    else
      numeric
    end
  end
  # #endregion metric formatters

  # TODO: FINISH SUMMARY
  # ### Parameters
  # * `array`: A sorted `Array` of `Numeric`s
  # * `excluded_keys`: An `Array` of `Symbols` denoting keys to exclude from the output; invalid
  # options are ignored. See `Return` for valid values.
  # * `zero_value`: What does a value of zero look like for the type of values in `array`; ensures
  # compatibility with stuff like `Duration`s.
  # ### Block
  # An optional formatter for the resultant values.
  # #### Parameters
  # * `numeric`: The calculated value to format
  # * `symbol` {`Symbol`|`nil`} [`nil`]: The metric for which `numeric` was calculated
  #
  # Returns the formatted value. Type doesn't matter as long as it's not `nil`.
  # ### Returns
  # A `Hash` with the following self-explanatory keys:
  # * `count`
  # * `sum`
  # * `median`
  # * `minimum`
  # * `maximum`
  # * `mean`
  # * `standard_deviation`
  def self.metrics(array, *excluded_keys, zero_value: 0.0, &)
    midpoints = array.length % 2 > 0 ? [(array.length / 2).floor, (array.length / 2).ceil] : (array.length / 2).floor
    ret = if array.empty?
            {
              count: 0,
              # sum: zero_value,
              # median: zero_value,
              # minimum: zero_value,
              # maximum: zero_value,
              # mean: zero_value,
              # standard_deviation: zero_value,
            }
          else
            ret = {
              count: array.length,
              sum: array.inject(zero_value, :+),
              median: midpoints.is_a?(Numeric) ? array[midpoints] : ((array[midpoints[0]] + array[midpoints[1]]) / 2),
              minimum: array.first,
              maximum: array.last,
            }
            ret[:mean] = ret[:sum] / array.length
            ret[:standard_deviation] = Math.sqrt(
              array.inject(0) do |acc, e|
                acc + ((e - ret[:mean])**2)
              end / array.length,
            )
            ret
          end
    if block_given?
      ret.each_pair { |k, v| ret[k] = yield(v, k) unless k == :count }
    end
    excluded_keys.each { |e| ret.delete(e) } if excluded_keys.present?
    ret
  end

  # Gets the requested subset of takedowns from the given array.
  # ### Parameters
  # * `symbol` {`Symbol`}: The filtration criteria.
  # * `array` {`Array`}: The array to filter.
  # * `:flagify` [`false`]: If `true`, instead of filtering the array, converts each parameter into
  # a `1` or `0` if the given criteria is true or false, respectively.
  # * `:user_id` {`Numeric`|`nil`}: An optional id to match when `symbol` is `:has_user` or
  # `:has_verified_user`.
  # ### Returns
  # If `flagify`, an `Array` the ordered true/false output of the filtration criteria; otherwise, an
  # `Array` of elements in `array` that matched the criteria.
  # ### Notes
  # OPTIMIZE: Prime candidate for optimization through reducing iterations.
  def self.filter_by(symbol, array, flagify: false, invert: false, **kwargs)
    v = case symbol
        when :approved, :denied, :partial, :inactive, :pending, :completed, :incompleted, :has_user, :has_verified_user, :has_approver
          # array.inject([]) { |accum, takedown| takedown.send(:"#{symbol}?") && !invert ? (accum << takedown) : accum }
          array.select { |takedown| takedown.send(:"#{symbol}?") && !invert }
        end
    if !invert && kwargs.key?(:user_id)
      if %i[has_user has_verified_user].include?(symbol)
        # v = v.inject([]) { |accum, takedown| takedown.creator_id == kwargs[:user_id] ? (accum << takedown) : accum }
        v = v.select { |takedown| takedown.creator_id == kwargs[:user_id] }
      elsif symbol == :has_approver
        # v = v.inject([]) { |accum, takedown| takedown.approver_id == kwargs[:user_id] ? (accum << takedown) : accum }
        v = v.select { |takedown| takedown.approver_id == kwargs[:user_id] }
      end
    end
    if flagify
      # t = kwargs.fetch(:true_flag, 1)
      # f = kwargs.fetch(:false_flag, 0)
      # v = array.map { |takedown| v.include?(takedown) ? t : f }
      v = array.map { |takedown| v.include?(takedown) ? 1 : 0 }
    end
    v
  end

  # Status conditions which ensure the takedown has been completed.
  #
  # Used to check if the given subset always has a completion time.
  COMPLETED_STATUSES = %i[approved denied partial completed].freeze

  # #region yield_numeric_stats_from Jump Table Methods
  private_class_method def self._collection(info, array, **)
    info[:collection] = array
    info
  end

  private_class_method def self._count(info, array, **)
    info[:metrics][:count] = array.length
    info
  end

  private_class_method def self._user_frequency(info, array, **)
    info[:metrics][:user_frequency] ||= {}
    array.each do |takedown|
      # key = takedown.creator_id.nil? ? :no_user : takedown.creator_id
      key = if takedown.creator_id.nil?
              :no_user
            # elsif takedown.creator
            #   { user_name: takedown.creator.name, user_id: takedown.creator_id }
            else
              :"#{takedown.creator_id}"
            end
      info[:metrics][:user_frequency][key] ||= 0
      info[:metrics][:user_frequency][key] += 1
    end
    info
  end

  private_class_method def self._post_counts(info, array, **)
    info[:metrics][:post_counts] = metrics(array.map(&:post_count).sort)
    info
  end

  private_class_method def self._has_user(info, array, **)
    info[:metrics][:has_user] = metrics(
      array.map { |takedown| takedown.creator_id.nil? ? 0 : 1 }.sort,
      :minimum, :maximum,
      &method(:flag_percent_formatter)
    )
    info
  end

  private_class_method def self._has_verified_user(info, array, **)
    info[:metrics][:has_verified_user] = metrics(
      array.map do |takedown|
        if takedown.creator_id.nil?
          0
        else
          Artist.where(linked_user_id: takedown.creator_id).exists? ? 1 : 0
        end
      end.sort,
      :minimum, :maximum,
      &method(:flag_percent_formatter)
    )
    info
  end

  private_class_method def self._has_approver(info, array, **)
    info[:metrics][:has_approver] = metrics(
      array.map { |takedown| takedown.creator_id.nil? ? 0 : 1 }.sort,
      :minimum, :maximum,
      &method(:flag_percent_formatter)
    )
    info
  end

  private_class_method def self._estimated_time_til_completion(info, array, is_completed:, **)
    if is_completed
      info[:metrics][:estimated_time_til_completion] = metrics(
        array.map { |takedown| takedown.updated_at - takedown.created_at }.sort,
        zero_value: 0.days,
        &method(:duration_formatter)
      )
    end
    info
  end

  private_class_method def self._approved(info, array, **)
    _generic_status(info, array, symbol: :approved, **)
  end

  private_class_method def self._denied(info, array, **)
    _generic_status(info, array, symbol: :denied, **)
  end

  private_class_method def self._partial(info, array, **)
    _generic_status(info, array, symbol: :partial, **)
  end

  private_class_method def self._inactive(info, array, **)
    _generic_status(info, array, symbol: :inactive, **)
  end

  private_class_method def self._pending(info, array, **)
    _generic_status(info, array, symbol: :pending, **)
  end

  private_class_method def self._completed(info, array, **)
    _generic_status(info, array, symbol: :completed, **)
  end

  private_class_method def self._incompleted(info, array, **)
    _generic_status(info, array, symbol: :incompleted, **)
  end

  private_class_method def self._generic_status(info, array, symbol:, **)
    info[symbol] = metrics(
      filter_by(symbol, array, flagify: true),
      :minimum, :maximum,
      &method(:flag_percent_formatter)
    )
    info
  end

  private_class_method def self._unimplemented(info, array, symbol:, **)
    raise NotImplementedError, "The requested symbol (#{symbol}) was not implemented."
    # info
  end

  YIELD_JUMP_TABLE = Hash.new(:_unimplemented).merge({
    collection: :_collection,
    count: :_count,
    user_frequency: :_user_frequency,
    post_counts: :_post_counts,
    has_user: :_has_user,
    has_verified_user: :_has_verified_user,
    estimated_time_til_completion: :_estimated_time_til_completion,
    approved: :_approved,
    denied: :_denied,
    partial: :_partial,
    inactive: :_inactive,
    pending: :_pending,
    completed: :_completed,
    incompleted: :_incompleted,
  }).freeze
  # #endregion yield_numeric_stats_from Jump Table Methods

  DEFAULT_YIELD_ITEMS = %i[count user_frequency post_counts has_user has_verified_user estimated_time_til_completion].freeze
  USER_SYMBOLS = %i[has_user has_verified_user has_approver].freeze
  TRUE_STATUS_SYMBOLS = %i[approved denied partial inactive pending].freeze
  ALL_STATUS_SYMBOLS = (%i[completed incompleted] + TakedownStatsUpdater::TRUE_STATUS_SYMBOLS).freeze

  DESCRIPTIONS = {
    count: "The number of takedowns in this grouping.",
    user_frequency: "How often each user was the one to submit a takedown in this grouping.",
    post_counts: "The number of posts takedowns in this group affect.",
    has_user: "Stats on how many takedowns in this group were submitted by a user.",
    has_verified_user: "Stats on how many takedowns in this group were submitted by a user linked to an artist.",
    estimated_time_til_completion: "Stats on how long takedowns in this group took to complete. Derived from last update time, will be inaccurate if edited afterwards.",
    completed: "Stats for completed takedowns in this group.",
    incompleted: "Stats for incompleted takedowns in this group.",
    approved: "Stats for approved takedowns in this group.",
    denied: "Stats for denied takedowns in this group.",
    partial: "Stats for partial takedowns in this group.",
    inactive: "Stats for inactive takedowns in this group.",
    pending: "Stats for pending takedowns in this group.",
    # last_month_takedowns:
  }.freeze

  SYMBOL_SNIPPETS = {
    has_user: "were submitted by a user",
    has_verified_user: "were submitted by a user linked to an artist",
    completed: "were resolved",
    incompleted: "are unresolved",
    approved: "were approved",
    denied: "were denied",
    partial: "were partially approved",
    inactive: "are inactive",
    pending: "are pending",
  }.freeze

  # TODO: FINISH DOCS
  # Generates the given suite of numerical statistics that can be derived from the given takedowns.
  # ### Parameters
  # * `array` {`Takedown[]`}:
  # * `items` {`Symbol[]`}: The keys to include in the output. Invalid keys are ignored.
  # Options are:
  # > * `count`:
  # > * `user_frequency`:
  # > * `post_counts`:
  # > * `has_user`:
  # > * `has_verified_user`:
  # > * `estimated_time_til_completion`:
  # > * `collection`:
  # > * `approved`:
  # > * `denied`:
  # > * `partial`:
  # > * `inactive`:
  # > * `pending`:
  # > * `completed`:
  # > * `incompleted`:
  # ### Returns
  #
  def self.yield_numeric_stats_from(
    array,
    is_completed: false,
    items: DEFAULT_YIELD_ITEMS,
    recursive_items: nil,
    **kwargs
  )
    info = { metrics: {} }
    if kwargs[:path].present?
      d_gen = ->(symbol) { SYMBOL_SNIPPETS[symbol] || symbol.to_s.titlize }
      info[:metrics][:group_description] = "Stats for all takedowns that "
      info[:metrics][:group_description] += case kwargs[:path].length
                                            when 1
                                              d_gen.call(kwargs[:path][0])
                                            when 2
                                              kwargs[:path].map { |e| d_gen.call(e) }.join(" and ")
                                            else
                                              "#{
                                                kwargs[:path]
                                                  .first(kwargs[:path].length - 1)
                                                  .map { |e| d_gen.call(e) }
                                                  .join(', ')
                                              }, and #{
                                                d_gen
                                                  .call(kwargs[:path]
                                                  .last)
                                              }"
                                            end
      info[:metrics][:group_description] += "."
    end
    items.each { |e| send(YIELD_JUMP_TABLE[e], info, array, is_completed: is_completed, symbol: e) }
    return info unless recursive_items.is_a?(Hash)
    recursive_items.each_pair do |k, v|
      if USER_SYMBOLS.include?(k) && v.is_a?(Hash) && v[:use_user_ids]
        sym = k.to_s[4..].to_sym
        (info[:metrics][:user_frequency][sym] ||= {})
          .merge!(
            (
              info.dig(:metrics, :user_frequency)&.keys ||
              array.pluck(&(k == :has_approver ? :approver_id : :creator_id)).uniq.compact
            ).index_with do |e|
              t_array = array.select { |el| el.creator_id == e }
              next nil if t_array.blank?
              # user = t_array.first.send(sym.to_s.end_with?("user") ? :creator : :approver)
              yield_numeric_stats_from(
                t_array,
                is_completed: is_completed,
                **(v.is_a?(Hash) ? v : {}),
                path: kwargs.fetch(:path, []) + [:user_frequency, sym],
              )
              # .merge({
              #   user_hash: {
              #     level_css_class: user.level_css_class,
              #     can_approve_posts?: user.can_approve_posts?,
              #     can_upload_free?: user.can_upload_free?,
              #     is_banned?: user.is_banned?,
              #     pretty_name: user.pretty_name,
              #     id: user.id,
              #     is_verified?: user.is_verified?,
              #   },
              # })
            end,
          )
        next
      end
      t_array = if v.is_a?(Hash) && v[:filter_hash]
                  filter_by(k, array, **(v[:filter_hash]))
                else
                  filter_by(k, array)
                end
      next if t_array.blank?
      (info[k] ||= {}).merge!(
        **yield_numeric_stats_from(
          t_array,
          is_completed: is_completed || COMPLETED_STATUSES.include?(k),
          **(v.is_a?(Hash) ? v : {}),
          path: kwargs.fetch(:path, []) + [k],
        ),
      )
    end
    info
  end

  # Make the statistics hash for the given collection of takedowns.
  # ### Parameters
  # * `takedowns`
  # ### Returns
  # A hash with these hashes:
  # * `submitted`
  # * `approved`
  # * `denied`
  # * `partial`
  # * `inactive`
  # * `pending`
  # * `completed`
  # * `incompleted`
  #
  # Those hashes have the following keys:
  def self.gen_main_stats(takedowns)
    # status_map = {
    #   # #region Simplest
    #   # completed: nil,
    #   # incompleted: nil,
    #   # approved: nil,
    #   # denied: nil,
    #   # partial: nil,
    #   # inactive: nil,
    #   # pending: nil,
    #   # #endregion Simplest
    #   # #region 2nd Simplest
    #   # completed: {
    #   #   items: DEFAULT_YIELD_ITEMS + COMPLETED_STATUSES - [:completed],
    #   # },
    #   # incompleted: {
    #   #   items: DEFAULT_YIELD_ITEMS + ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted],
    #   # },
    #   # #endregion 2nd Simplest
    #   # #region Most complex
    #   completed: {
    #     items: COMPLETED_STATUSES - [:completed] + DEFAULT_YIELD_ITEMS,
    #     recursive_items: (COMPLETED_STATUSES - [:completed]).index_with { |_e| nil },
    #   },
    #   incompleted: {
    #     items: ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted] + DEFAULT_YIELD_ITEMS,
    #     recursive_items: (ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted]).index_with { |_e| nil },
    #   },
    #   # #endregion Most complex
    # }
    # user_frequency_map = {
    #   has_user: {
    #     use_user_ids: true,
    #     items: ALL_STATUS_SYMBOLS + DEFAULT_YIELD_ITEMS - %i[user_frequency has_user has_verified_user],
    #     recursive_items: status_map.deep_dup,
    #   },
    # }
    # [status_map[:completed][:recursive_items], status_map[:incompleted][:recursive_items]].each do |h|
    #   h.transform_values! do |_v|
    #     { recursive_items: { has_user: { use_user_ids: true } }, items:  }
    #   end
    # end
    yield_numeric_stats_from(
      takedowns,
      items: ALL_STATUS_SYMBOLS + DEFAULT_YIELD_ITEMS,
      recursive_items: {
        # #region Simplest
        # completed: nil,
        # incompleted: nil,
        # approved: nil,
        # denied: nil,
        # partial: nil,
        # inactive: nil,
        # pending: nil,
        # #endregion Simplest
        # #region 2nd Simplest
        # completed: {
        #   items: DEFAULT_YIELD_ITEMS + COMPLETED_STATUSES - [:completed],
        # },
        # incompleted: {
        #   items: DEFAULT_YIELD_ITEMS + ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted],
        # },
        # #endregion 2nd Simplest
        # #region Most complex
        completed: {
          items: COMPLETED_STATUSES - [:completed] + DEFAULT_YIELD_ITEMS,
          recursive_items: (COMPLETED_STATUSES - [:completed]).index_with { |_e| nil },
        },
        incompleted: {
          items: ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted] + DEFAULT_YIELD_ITEMS,
          recursive_items: (ALL_STATUS_SYMBOLS - COMPLETED_STATUSES - [:incompleted]).index_with { |_e| nil },
        },
        # #endregion Most complex
      },
    )
  end

  def self.run!
    stats = {}
    begin
      stats[:started_posts] = Post.find(Post.minimum("id")).created_at
      stats[:started_takedowns] = Takedown.find(Takedown.minimum("id")).created_at
    rescue StandardError => error # rubocop:disable Naming/RescuedExceptionsVariableName
      puts "Failed: #{error}"
      return
    end

    now = Time.now
    daily_average = ->(total, sym: :started_takedowns) do
      (total / ((now - stats[sym]) / (60 * 60 * 24))).round
    end

    ### Takedowns ###

    stats[:total_takedown_ids] = Takedown.maximum("id")
    all_takedowns = Takedown.all
    stats[:total_takedowns] = gen_main_stats(all_takedowns) # .merge(gen_non_status_stats(all_takedowns, include_submitted: false))
    stats[:last_months_takedowns] = gen_main_stats(Takedown.where("created_at >= ?", now.months_ago(1)))

    stats[:user_takedowns] = Takedown.where.not(creator_id: nil)
    stats[:non_user_takedowns] = Takedown.where(creator_id: nil)

    ### Users ###

    stats[:users_counts] = stats[:user_takedowns].group(:creator_id).count
    stats[:total_users] = stats[:users_counts].length
    Takedown.joins(creator: { artists: :linked_user_id })
    stats[:total_verified_users_count] = Takedown.joins("INNER JOIN #{User.table_name} ON #{User.table_name}.id = #{Takedown.table_name}.creator_id INNER JOIN #{Artist.table_name} ON #{Artist.table_name}.linked_user_id = #{User.table_name}.id").group(:creator_id).count
    stats[:user_stats] = stats[:users_counts].keys.to_h do |creator_id|
      takedowns = stats[:user_takedowns].select { |e| e.creator_id == creator_id }
      [
        creator_id,
        TakedownStatsUpdater.gen_main_stats(takedowns),
      ]
    end

    stats[:posts_per_request] = TakedownStatsUpdater.metrics(Takedown.all.map(&:post_count).sort)

    Cache.redis.set("e6stats_takedown", stats.to_json)
  end
end
