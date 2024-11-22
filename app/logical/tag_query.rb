# frozen_string_literal: true

class TagQuery
  class CountExceededError < StandardError
    def initialize(msg = "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time")
      super(msg)
    end
  end

  class CountExceededWithDataError < CountExceededError
    delegate :[], :include?, to: :@q
    attr_reader :q, :resolve_aliases, :tag_count

    def initialize(msg = "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time", query_obj:, resolve_aliases:, tag_count:)
      @q = query_obj
      @resolve_aliases = resolve_aliases
      @tag_count = tag_count
      super(msg)
    end
  end

  COUNT_METATAGS = %w[
    comment_count
  ].freeze

  BOOLEAN_METATAGS = %w[
    hassource hasdescription isparent ischild inpool pending_replacements artverified
  ].freeze

  NEGATABLE_METATAGS = %w[
    id filetype type rating description parent user user_id approver flagger deletedby delreason
    source status pool set fav favoritedby note locked upvote votedup downvote voteddown voted
    width height mpixels ratio filesize duration score favcount date age change tagcount
    commenter comm noter noteupdater
  ] + TagCategory::SHORT_NAME_LIST.map { |tag_name| "#{tag_name}tags" }

  METATAGS = %w[
    md5 order limit child randseed ratinglocked notelocked statuslocked
  ] + NEGATABLE_METATAGS + COUNT_METATAGS + BOOLEAN_METATAGS

  ORDER_METATAGS = %w[
    id id_desc
    score score_asc
    favcount favcount_asc
    created_at created_at_asc
    updated updated_desc updated_asc
    comment comment_asc
    comment_bumped comment_bumped_asc
    note note_asc
    mpixels mpixels_asc
    portrait landscape
    filesize filesize_asc
    tagcount tagcount_asc
    change change_desc change_asc
    duration duration_desc duration_asc
    rank
    random
  ] + COUNT_METATAGS + TagCategory::SHORT_NAME_LIST.flat_map { |str| ["#{str}tags", "#{str}tags_asc"] }

  ##
  # Only these tags hold global meaning and don't have added meaning by being in a grouped context.
  # Therefore, these should be pulled out of groups
  GLOBAL_METATAGS = %w[
    order limit randseed
  ].freeze

  delegate :[], :include?, to: :@q
  attr_reader :q, :resolve_aliases, :tag_count

  def initialize(query, resolve_aliases: true, free_tags_count: 0, return_with_count_exceeded: false, process_groups: false)
    @q = {
      tags: {
        must: [],
        must_not: [],
        should: [],
      },
      groups: {
        must: [],
        must_not: [],
        should: [],
      },
    }
    @resolve_aliases = resolve_aliases
    @tag_count = 0
    @free_tags_count = free_tags_count

    parse_query(query, process_groups: process_groups)
    if @tag_count > Danbooru.config.tag_query_limit - free_tags_count
      if return_with_count_exceeded
        raise CountExceededWithDataError.new(query_obj: @q, resolve_aliases: @resolve_aliases, tag_count: @tag_count)
      else
        raise CountExceededError, "You cannot search for more than #{Danbooru.config.tag_query_limit} tags at a time"
      end
    end
  end

  def total_tag_count
    @tag_count + @free_tags_count
  end

  def self.normalize(query)
    tags = TagQuery.scan(query)
    tags = tags.map { |t| Tag.normalize_name(t) }
    tags = TagAlias.to_aliased(tags)
    tags.sort.uniq.join(" ")
  end

  def self.normalize_tag_array(tags, strip_duplicates: false, handle_prefixes: true)
    modifiers = []
    tags = tags.map do |t|
      if handle_prefixes
        m = /\A([-~]?).*\z/.match(t)
        modifiers << m[1]
      end
      Tag.normalize_name(t)
    end
    tags = TagAlias.to_aliased(tags)
    tags.map! { |t| "#{modifiers.slice!(0)}#{t}" } if handle_prefixes
    (strip_duplicates ? tags.uniq : tags)
  end

  ##
  # Convert query into a consisent representation.
  # * Converts to string
  # * Unicode normalizes w/ nfc
  # * Converts to lowercase
  # * Removes leading & trailing whitespace
  # * Converts interior whitespace to underscores
  # * Resolves tag aliases
  def self.normalize_search(
    query,
    sort: true,
    strip_all_duplicates: false,
    strip_duplicates_at_level: true,
    # handle_prefixes: true
    strip_prefixes: true
  )
    tags = scan_recursive(
      query,
      strip_duplicates_at_level: strip_duplicates_at_level,
      strip_prefixes: strip_prefixes,
      sort_at_level: sort,
      normalize_at_level: true,
    )
    # tags = normalize_tag_array(
    #   scan_recursive(
    #     query,
    #     strip_duplicates_at_level: strip_duplicates_at_level,
    #     # strip_prefixes: handle_prefixes,
    #     sort_at_level: sort,
    #     normalize_at_level: true,
    #   ),
    #   strip_duplicates: strip_all_duplicates,
    #   handle_prefixes: handle_prefixes,
    # )
    (strip_all_duplicates ? tags.uniq : tags).join(" ")
  end

  def self.tokenize_regex
    /\G(?<prefix>[-~])?(?<body>(?<metatag>(?>\w*:"[^"]*"))|(?<group>(?>(?>\(\s+)(?>(?!(?<=\s)\))(?>[-~]?\g<metatag>|[-~]?\g<group>|(?>[^\s)]+|(?<!\s)\))*)(?>\s*)|(?=(?<=\s)\)))+(?<=\s)\)))|(?<tag>\S+))(?>\s*)/
  end

  def self.match_tokens_redux(
    tagstr,
    recurse: false,
    stop_at_group: false,
    &block
  )
    tagstr = tagstr.to_s.unicode_normalize(:nfc).strip
    r = []
    if recurse
      tagstr.scan(tokenize_regex) do |_|
        m = Regexp.last_match
        if m[:group].blank?
          r << block_given? ? block.call(m) : m
        else
          t = -> { block_given? ? scan_tokens_redux(m[:group][/\A\(\s+(.*)\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group, &block) : scan_tokens_redux(m[:group][/\A\(\s+(.*)\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group) }
          if stop_at_group
            r << block_given? ? block.call(m) : m
          end
          r << t.call
        end
      end
    else
      block_given? ? tagstr.scan(tokenize_regex) { |_| r << block.call(Regexp.last_match) } : tagstr.scan(tokenize_regex) { |_| r << Regexp.last_match }
    end
    r
  end

  def self.scan_tokens_redux(
    tagstr,
    recurse: false,
    stop_at_group: false,
    &block
  )
    tagstr = tagstr.to_s.unicode_normalize(:nfc).strip
    r = []
    if recurse
      tagstr.scan(tokenize_regex) do |_|
        m = Regexp.last_match
        if m[:group].blank?
          r << block_given? ? block.call(m[:prefix] + m[:body]) : m[:prefix] + m[:body]
        else
          t = -> { block_given? ? scan_tokens_redux(m[:group][/\A\(\s+(.*)\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group, &block) : scan_tokens_redux(m[:group][/\A\(\s+(.*)\s+\)\z/, 1], recurse: recurse, stop_at_group: stop_at_group) }
          if stop_at_group
            r << block_given? ? block.call(m[:prefix] + m[:body]) : m[:prefix] + m[:body]
          end
          r << t.call
        end
      end
    else
      block_given? ? tagstr.scan(tokenize_regex) { |m| r << block.call(m[:prefix] + m[:body]) } : tagstr.scan(tokenize_regex) { |m| r << m }
    end
    r
  end

  # def self.find_groups(
  #   tagstr,
  #   return_on: false,
  #   sort: true,
  #   recurse: true,
  #   from_modifier: true,
  #   filter_on: nil,
  #   max_iterations: Danbooru.config.tag_query_limit,
  #   &block
  # )
  #   # Limit search area
  #   enclosing = /\(\s.*\s\)/.match(tagstr)
  #   return nil unless enclosing
  #   offset = enclosing.begin(0)
  #   tagstr.slice!(0, enclosing.end(0))
  #   opens = nil
  #   closes = nil
  #   regex = /\A(?<pre>.*?)(?:(?<open>#{from_modifier ? '[-~]?' : ''}\(\s+)|\s+(?<close>\)))/
  #   while (curr_match = regex.match(tagstr, offset))
  #     unless curr_match[:pre][/\w*?:"[^"]*\z/] && curr_match.post_match.include?('"')
  #       if (curr_match[:open] || "").empty?
  #         closes ||= []
  #         closes << (curr_match.begin(:close) + offset)
  #       else
  #         opens ||= []
  #         opens << (curr_match.begin(:open) + offset)
  #       end
  #     end
  #     offset += curr_match.end(0)
  #   end
  #   return nil unless opens && closes
  #   v = nil
  #   block_vals = nil
  #   loop_count = 0
  #   # unmatched_closes = nil
  #   while !opens.empty? && !closes.empty? && (max_iterations ? loop_count < max_iterations : true)
  #     i = 0
  #     i += 1 while opens[i] && closes[0] && opens[i] < closes[0]
  #     i -= 1
  #     if i < 0
  #       # unmatched_closes ||= []
  #       # unmatched_closes << closes.slice!(0)
  #       closes.slice!(0)
  #       next
  #     end
  #     open = opens.slice!(i)
  #     close = closes.slice!(0)
  #     nbe = nil
  #     if filter_on == (block_given? ? (nbe = block.call(open, close)) : [open, close])
  #       loop_count += 1
  #       next
  #     end
  #     v ||= []
  #     block_vals ||= [] if block_given?
  #     v, block_vals, do_return = as_we_go(
  #       open,
  #       close,
  #       [v, block_vals],
  #       new_block_elem: nbe,
  #       return_on: return_on,
  #       sort: sort,
  #       recurse: recurse,
  #     )
  #     loop_count += 1
  #     break if do_return
  #   end
  #   # unmatched_opens = opens unless opens.empty?
  #   if sort || recurse
  #     block_vals || v
  #   elsif block_given?
  #     to_remove = nil
  #     v.each_with_index do |e, ind|
  #       to_remove = (to_remove || []) << ind if v.any? { |e1| e.first > e1.first && e.last < e1.last }
  #     end
  #     to_remove.each do |ind|
  #       v.delete_at(ind)
  #       block_vals&.delete_at(ind)
  #     end
  #     block_vals || v
  #   else
  #     v.filter! do |e|
  #       v.any? { |e1| e.first > e1.first && e.last < e1.last }
  #     end || v
  #   end
  # end
  # ##
  # # Handles sorting and recursion as elements come in rather than after completion
  # def self.as_we_go(
  #   open,
  #   close,
  #   curr_results,
  #   new_block_elem: nil,
  #   return_on: nil,
  #   sort: true,
  #   recurse: false
  # )
  #   # results, block_results = new_block_elem ? curr_results : [curr_results, nil]
  #   results, block_results = curr_results
  #   new_elem = [open, close]
  #   r_v = block_results ? return_on == new_block_elem : return_on == new_elem
  #   return_value = false
  #   if sort
  #     if recurse
  #       ind = results.index { |e| e.first > open } || results.length
  #       results.insert(ind, new_elem)
  #       block_results&.insert(ind, new_block_elem)
  #       return_value = r_v
  #     elsif results.empty?
  #       results << new_elem
  #       block_results << new_block_elem if block_results
  #       return_value = r_v
  #     else
  #       match_index = results.index { |e| e.first > open } || results.length
  #       insertion_index = match_index
  #       curr_index = match_index - 1
  #       while curr_index >= 0
  #         if results[curr_index].last > close
  #           insertion_index = nil
  #           break
  #         else
  #           curr_index -= 1
  #         end
  #       end
  #       curr_index = match_index
  #       while curr_index < results.length
  #         if results[curr_index].last < close
  #           results.slice!(curr_index)
  #           block_results&.slice!(curr_index)
  #         else
  #           curr_index += 1
  #         end
  #       end
  #       if insertion_index > 0
  #         results.insert(insertion_index, new_elem)
  #         block_results&.insert(insertion_index, new_elem)
  #         return_value = r_v
  #       else
  #         return_value = false
  #       end
  #     end
  #   else
  #     results << new_elem
  #     block_results << new_block_elem if block_results
  #     return_value = r_v
  #   end
  #   [results, block_results, return_value || return_on == (block_results || results)]
  # end
  # def self.find_no_groups(
  #   tagstr,
  #   filter_on: nil,
  #   return_on: nil,
  #   from_modifier: true,
  #   max_iterations: Danbooru.config.tag_query_limit,
  #   &block
  # )
  #   v = nil
  #   pre = ""
  #   loop_count = 0
  #   while loop_count < max_iterations && (curr_match = /\A#{from_modifier ? '' : '(?<modifier>[-~]?)'}(?<tag>\w*:"[^"]*"|\S+)(?:\z|\s*)/.match(tagstr, offset))
  #     v ||= []
  #     open = curr_match.begin(:tag) + pre.length
  #     close = curr_match.end(:tag) - 1 + pre.length
  #     if block_given?
  #       v = block.call(open, close, v)
  #       return v if (v.respond_to?(:last) && v.last == return_on) || v == return_on
  #     else
  #       v << [open, close]
  #       return v if return_on == [open, close] || v == return_on
  #     end
  #     pre += curr_match.pre_match + curr_match[0]
  #     tagstr = curr_match.post_match
  #     loop_count += 1
  #   end
  #   v
  # end
  # # TODO: Add fields for precomputed groups?
  # def self.find_tokens(
  #   tagstr,
  #   return_on: nil,
  #   sort: true,
  #   recurse: false,
  #   filter_on: nil,
  #   from_modifier: true,
  #   max_iterations: Danbooru.config.tag_query_limit,
  #   &block
  # )
  #   unless might_have_groups?(tagstr)
  #     if block_given?
  #       return find_no_groups(tagstr, return_on: return_on, from_modifier: from_modifier, max_iterations: max_iterations, &block)
  #     else
  #       return find_no_groups(tagstr, return_on: return_on, from_modifier: from_modifier, max_iterations: max_iterations)
  #     end
  #   end
  #   loop_count = 0
  #   v_group = nil
  #   do_return = false
  #   last_e = nil
  #   temp_ret_on = return_on == true ? 1 : true
  #   v = find_groups(
  #     tagstr,
  #     return_on: block_given? && !sort && recurse ? temp_ret_on : return_on,
  #     filter_on: filter_on,
  #     from_modifier: from_modifier,
  #     max_iterations: max_iterations,
  #     sort: sort,
  #   ) do |open, close|
  #     loop_count += 1
  #     if block_given? && !sort && recurse
  #       new_e = block.call(open, close)
  #       if new_e == return_on
  #         do_return = true
  #         last_e = new_e
  #         temp_ret_on
  #       else
  #         [[open, close], new_e]
  #       end
  #     else
  #       [open, close]
  #     end
  #   end
  #   v[v.index { |e| e.last == temp_ret_on }][-1] = last_e if do_return
  #   v_group = block_given? && !sort && recurse ? v.to_h { |e| [{ open: e.first, close: e[1] }, e.last] } : v.index_by { |e| { open: e.first, close: e.last } }
  #   return v_group.values if do_return || loop_count >= max_iterations
  #   if v.blank?
  #     if block_given?
  #       return find_no_groups(tagstr, return_on: return_on, from_modifier: from_modifier, max_iterations: max_iterations, &block)
  #     else
  #       return find_no_groups(tagstr, return_on: return_on, from_modifier: from_modifier, max_iterations: max_iterations)
  #     end
  #   end
  #   pre = ""
  #   reg_prefix = from_modifier ? "(?<tag>(?<modifier>[-~]?)" : "(?<modifier>[-~]?)(?<tag>"
  #   v = []
  #   v_group.each_key do |e|
  #     while e[:open] > pre.length
  #       loop_count += 1
  #       curr_match = /\A#{reg_prefix}\w*:"[^"]*"|\S+)(?:\z|\s*)/.match(tagstr)
  #       raise "No match" unless curr_match
  #       open = curr_match.begin(:tag) + pre.length
  #       close = curr_match.end(:tag) - 1 + pre.length
  #       if block_given?
  #         v << block.call(open, close)
  #         return v if (v.respond_to?(:last) && v.last == return_on) || return_on == [open, close] || v == return_on
  #       else
  #         v << [open, close]
  #         return v if v.last == return_on || v == return_on
  #       end
  #       pre += curr_match.pre_match + curr_match[0]
  #       tagstr = curr_match.post_match
  #     end
  #     unless pre.length - 1 == e[:open] || (!from_modifier && pre.length == e[:open] && tagstr[0][/\A[-~]\z/])
  #       raise "#{pre} does not reach position #{e[:open]} characters disregarding modifiers"
  #     end
  #     if block_given?
  #       if !sort && recurse
  #         v << v_group[e]
  #         return v if v_group[e] == return_on || v == return_on
  #       else
  #         v << block.call(e[:open] + (from_modifier && tagstr[0][/\A[-~]\z/] ? 1 : 0), e[:close])
  #         return v if v.last == return_on || v == return_on
  #       end
  #     else
  #       v << [e[:open], e[:close]]
  #       return v if v.last == return_on || v == return_on
  #     end
  #     substr = recurse ? tagstr.match(/\A[-~]?\(\s+/)[0] : (tagstr[0..(e[:close] - pre.length)] + (tagstr.match(/\A\s*/, e[:close] - pre.length + 1) || [""])[0])
  #     tagstr.slice!(0, substr.length)
  #     pre += substr
  #   end
  #   v
  # end
  # ##
  # # Matches each group, correctly capturing groups; is recursive.
  # def self.match_groups(
  #   tagstr,
  #   return_on: nil,
  #   sort: true,
  #   recurse: false,
  #   filter_on: nil,
  #   from_modifier: true,
  #   max_iterations: Danbooru.config.tag_query_limit,
  #   &block
  # )
  #   find_groups(
  #     tagstr,
  #     return_on: return_on,
  #     sort: sort,
  #     recurse: recurse,
  #     filter_on: filter_on,
  #     from_modifier: from_modifier,
  #     max_iterations: max_iterations,
  #   ) do |open, close|
  #     pre = tagstr[0..open - 1] || ""
  #     post = tagstr[close + 1..] || ""
  #     curr_match = /\A(?<before>#{pre})(?<group>\(\s+(?<body>.*?)\s+\))(?<after>#{post})\z/.match(tagstr)
  #     block_given? ? block.call(curr_match) : curr_match
  #   end
  # end
  # ##
  # # Matches each token, presuming groups either aren't present or are not being processed.
  # def self.match_no_groups(query, &block)
  #   tagstr = query.to_s.unicode_normalize(:nfc).strip
  #   matches = []
  #   pre = ""
  #   post = ""
  #   # This preserves quoted metatags and groups w/o altering order.
  #   # while (curr_match = /\A([-~]?(?:\w*?:".*?"|\(\s.*?\s\)|\S+))(?:\s*|\z)/.match(tagstr))
  #   while (curr_match = /(?<=\A#{Regexp.escape(pre)})([-~]?(?:\w*?:".*?"|\S+))(?:\s*|\z)(?=#{Regexp.escape(post)}\z)/.match(tagstr))
  #     pre = curr_match.pre_match
  #     post = curr_match.post_match
  #     if block_given?
  #       matches << block.call(curr_match)
  #     else
  #       matches << curr_match
  #     end
  #   end
  #   matches
  # end
  # # TODO: Optimize
  # def self.match_tokens(tagstr, recurse: false, &block)
  #   v = find_groups(tagstr, recurse: recurse)
  #   return scan_no_groups(query, block) if v.blank?
  #   str_length = tagstr.length
  #   curr_start = 0
  #   curr_end = str_length - 1
  #   pre = ""
  #   post = ""
  #   ret = []
  #   # prior_ranges = [] if recurse
  #   backtracks = nil
  #   while (curr_match = /(?<=\A#{Regexp.escape(pre)})\s*(?<token>(?<modifier>[-~]?)(?<tag>\w*?:".*?"|(?<open>\()\s+.*?\s+(?<close>\))|\S+(?=\s|\z)))#{post.empty? ? '' : "?(?=#{Regexp.escape(post)}\z)"}/.match(tagstr))
  #     # Update start & end then check if curr_match correctly matches (avoids errors w/ nested groups)
  #     p = -> {
  #       curr_start, curr_end = v.slice!(0)
  #       # prior_ranges << [curr_start, curr_end] if recurse
  #       backtracks = (curr_start + 1) if recurse
  #       curr_match.begin(:close) == curr_end && curr_match.begin(:open) == curr_start
  #     }
  #     # If this match is
  #     #   * a group,
  #     #   * there's still stored groups,
  #     #   * at or before the earliest group, and
  #     #   * not correctly aligned w/ the group
  #     # then skip this; this will happen next iteration.
  #     unless !v.empty? && curr_match[:open] && curr_match.begin(:open) >= v.first.first && !p.call
  #       if block_given?
  #         ret << block.call(curr_match)
  #       else
  #         ret << curr_match
  #       end
  #       tagstr.match(/\A\s*/, curr_match.end(0))
  #       curr_start = backtracks || curr_match.end(0)
  #       curr_end = str_length - 1
  #       backtracks = nil
  #     end
  #     pre = tagstr[0..(curr_start - 1)]
  #     post = tagstr[(curr_end + 1)..] || ""
  #   end
  #   ret
  # end
  # ##
  # # Generates an array of tokens, correctly capturing groups; is recursive.
  # def self.scan_groups(tagstr, recurse: true, return_on: nil, &block)
  #   find_groups(tagstr, return_on: return_on) do |open, close, v|
  #     if block_given?
  #       v << block.call(tagstr.slice(open, close))
  #       return v if v.last == return_on
  #     else
  #       v << tagstr.slice(open, close)
  #     end
  #   end
  # end
  # ##
  # # Generates an array of tokens, presuming groups either aren't present or are not being processed.
  # def self.scan_no_groups(query, &block)
  #   tagstr = query.to_s.unicode_normalize(:nfc).strip
  #   matches = []
  #   # This preserves quoted metatags and groups w/o altering order.
  #   while (curr_match = /\A(?<token>[-~]?(?>(?<mt>\w*?:"[^"]*")|\S+))(?:\z|(?<mt>\s*|\s+))/.match(tagstr))
  #     tagstr = curr_match.post_match
  #     if block_given?
  #       matches << block.call(curr_match[:token])
  #     else
  #       matches << curr_match[:token]
  #     end
  #   end
  #   matches
  # end
  # def self.scan_tokens(
  #   tagstr,
  #   return_on: nil,
  #   sort: true,
  #   recurse: false,
  #   filter_on: nil,
  #   from_modifier: true,
  #   max_iterations: Danbooru.config.tag_query_limit,
  #   &block
  # )
  #   find_tokens(
  #     tagstr,
  #     return_on: return_on,
  #     sort: sort,
  #     recurse: recurse,
  #     filter_on: filter_on,
  #     from_modifier: from_modifier,
  #     max_iterations: max_iterations,
  #   ) { |open, close| block_given? ? block.call(tagstr[open..close]) : tagstr[open..close] }
  # end

  # HACK: Check if filtering quoted metatags and then searching for a group is faster (it likely is)
  def self.has_groups?(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    while (curr_match = /\A[-~]?(?:(?<mt>\w*:"[^"]*")|(?<group>\(\s.*?\s\))|\S+(?=\s|\z))(?:\z|\s*)/.match(tagstr))
      return true if curr_match[:group].present?
      tagstr = curr_match.post_match
    end
    false
  end

  def self.might_have_groups?(query)
    /\(\s.*?\s\)/.match?(query.to_s.unicode_normalize(:nfc).strip)
  end

  ##
  # This will only pull the tags in +hoisted_metatags+ up to the top level
  def self.scan_search(query, hoisted_metatags: TagQuery::GLOBAL_METATAGS)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    # Quick exit if given an empty search
    return [] if tagstr.empty? || tagstr[/\A[-~]?\(\s+\)\z/].present?
    matches = []
    hoist_regex_stub = nil
    match_tokens_redux(tagstr, recurse: false) do |m|
      # If this query is composed of 1 top-level group with no modifiers, convert to ungrouped.
      if m.begin(:group) == 0 && m.end(:group) == tagstr.length
        return matches = scan_search(
          tagstr = m[:group][/\A\(\s+(.*)\s+\)\z/, 1],
          hoisted_metatags: hoisted_metatags,
        )
        # This will change the tag order, putting the hoisted tags in front of the groups that previously contained them
      elsif m[:group].present? && hoisted_metatags.present? &&
            m[:group][/#{hoist_regex_stub ||= [hoisted_metatags].inject(nil) { |prior, e| prior ? "#{prior}|#{e}" : e }}:\S+/]
        cb = ->(sub_match) do
          # if there's a group w/ a hoisted tag,
          if sub_match[:group].present? && sub_match[:group][/#{hoist_regex_stub}:\S+/]
            g = sub_match[0][/\(\s+(.*)\s+\)/]
            r_output = scan_tokens_redux(g[1], recurse: false, stop_at_group: true, &cb).inject("") { |p, c| p + c }
            (sub_match[0][0, g.begin(1)] + r_output + sub_match[0][g.end(1)..])
          elsif (sub_match[:metatag].present? && sub_match[:metatag][/\A#{hoist_regex_stub}:"[^"]"\z/]) ||
                (sub_match[:tag].present? && sub_match[:tag][/\A#{hoist_regex_stub}:\S+\z/])
            matches << ((sub_match[:prefix] || "") + sub_match[:metatag])
            ""
          else
            sub_match[0]
          end
        end
        matches << cb.call(m)
      else
        matches << ((m[:prefix] || "") + m[:body])
      end
    end
    matches
  end

  ##
  # TODO: If elastic_post_version_query_builder should allow the grouped syntax, modify elastic_post_version_query_builder.rb:44 to enable
  def self.scan(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    matches = []
    while (m = tagstr.match(/[-~]?\w*?:".*?"/))
      if m.begin(0) >= 0 then matches.push(*tagstr.slice!(0, m.end(0))[0, m.begin(0)].split) end
      matches << m[0]
      ""
    end
    matches.push(*tagstr.split) if tagstr.present?
    matches.uniq
  end

  def self.scan_legacy(query)
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    quote_delimited = []
    tagstr = tagstr.gsub(/[-~]?\w*?:".*?"/) do |match|
      quote_delimited << match
      ""
    end
    quote_delimited + tagstr.split.uniq
  end

  ##
  # TODO: Add hoisted tag support
  # TODO: Convert from match_tokens_redux to using the regexp directly
  # +strip_duplicates_at_level+: Removes any duplicate tags at the
  # current level, and recursively do the same for each group.
  # +delimit_groups+: Surround groups w/ parentheses elements. Unless +strip_prefixes+ or
  # +distribute_prefixes+ are truthy, preserves prefix.
  def self.scan_recursive(
    query,
    strip_duplicates_at_level: false,
    delimit_groups: true,
    flatten: true,
    strip_prefixes: false,
    # hoisted_metatags: nil,
    sort_at_level: false,
    normalize_at_level: false,
    distribute_prefixes: nil
  )
    tagstr = query.to_s.unicode_normalize(:nfc).strip
    matches = []
    last_group_index = -1
    group_ranges = [] if flatten
    top = flatten ? [] : nil
    # hoist_regex_stub = nil
    match_tokens_redux(tagstr, recurse: false, stop_at_group: true) do |m|
      distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
      # If this query is composed of 1 top-level group (with or without modifiers), handle that here
      if (m.begin(:group) == 0 || m.begin(:group) == 1) && m.end(:group) == tagstr.length
        tagstr = m[:body]
        matches = TagQuery.scan_recursive(
          # m[:body][/\A\(\s+(.*)\s+\)\z/, 1],
          m[:body][/\A\(\s+\)\z/] ? "" : m[:body][/\A\(\s+(.*)\s+\)\z/, 1],
          strip_duplicates_at_level: strip_duplicates_at_level,
          delimit_groups: delimit_groups,
          flatten: flatten,
          strip_prefixes: strip_prefixes,
          # hoisted_metatags: hoisted_metatags,
          sort_at_level: sort_at_level,
          normalize_at_level: normalize_at_level,
          distribute_prefixes: distribute_prefixes,
        )
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
        if delimit_groups
          matches.insert(0, "#{strip_prefixes || distribute_prefixes ? '' : m[:prefix]}(") << ")"
          return flatten ? matches : (matches = [matches])
        elsif !(strip_prefixes || distribute_prefixes) && m[:prefix].present?
          # TODO: What should be done when not stripping modifiers & not delimiting groups?
          # Either place the modifier alone outside the array or inside the array?
          # This won't correctly reconstitute the original string without dedicated code.
          # Currently places alone inside if flattening and outside otherwise
          # If flattening and not delimiting, modifier application is unable to be determined,
          # so remove entirely? Change options to force validity or split into 2 methods?
          return matches = flatten ? matches.insert(0, m[:prefix]) : [m[:prefix], matches]
        else
          return flatten ? matches : (matches = [matches])
        end
      elsif m[:group].present?
        distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
        value = TagQuery.scan_recursive(
          # m[0].strip,
          # "#{resolve_distributed_tag(distribute_prefixes) || m[:prefix]}#{m[:body]}",
          m[0].strip,
          strip_duplicates_at_level: strip_duplicates_at_level,
          delimit_groups: delimit_groups,
          flatten: flatten,
          strip_prefixes: strip_prefixes,
          # hoisted_metatags: hoisted_metatags,
          sort_at_level: sort_at_level,
          normalize_at_level: normalize_at_level,
          distribute_prefixes: distribute_prefixes,
        )
        distribute_prefixes << m[:prefix] if distribute_prefixes && m[:prefix].present?
        is_duplicate = false
        dup_check = ->(e) { e.empty? ? value.empty? : e.difference(value).blank? }
        if strip_duplicates_at_level
          if flatten
            # matches.each_cons(value.length) { |e| is_duplicate = true if e == value }
            matches.each_cons(value.length) { |e| is_duplicate = true if is_duplicate || dup_check.call(e) }
          else
            is_duplicate = matches.any?(&dup_check)
          end
        end
        unless is_duplicate
          # splat regardless of flattening to correctly de-nest value
          if sort_at_level
            group_ranges << ((last_group_index + 1)..(last_group_index + value.length)) if flatten
            matches.insert(last_group_index += value.length, *value)
          else
            matches.push(*value)
          end
        end
      else
        prefix = !strip_prefixes && (m[:prefix] || distribute_prefixes) ? resolve_distributed_tag(distribute_prefixes) || m[:prefix] : ""
        value = prefix + (normalize_at_level ? normalize_single_tag(m[:body]) : m[:body])
        unless strip_duplicates_at_level && (top || matches).include?(value)
          matches << value
          top << value if flatten
        end
      end
      distribute_prefixes.slice!(-1) if distribute_prefixes && m[:prefix].present?
    end
    if sort_at_level
      if last_group_index >= 0
        pre = matches.slice!(0, last_group_index + 1)
        pre = flatten ? group_ranges.map { |e| pre.slice(e) }.sort!.flatten! : pre.sort
      end
      matches.sort!
      if last_group_index >= 0
        matches.insert(0, *pre)
      end
    end
    matches
  end

  private_class_method def self.resolve_distributed_tag(distribution)
    return distribution unless distribution
    distribution.include?("-") ? "-" : distribution[-1]
  end

  # private_class_method def self.build_strip_prefixes(strip_minus: true, strip_tilde: true)
  #   { "-" => strip_minus, "~" => strip_tilde }
  # end

  # private_class_method def self.resolve_prefix(prefix, strip_prefixes)
  #   return "" unless prefix && strip_prefixes && strip_prefixes.respond_to?(:[])
  #   strip_prefixes[prefix] == true ? "" : prefix
  # end

  ##
  # takes the following block:
  #   pre: the unmatched text between the start/last match and the current match
  #   contents: the entire matched metatag, including its name
  #   post: the remaining text to test
  #   tag: the matched tag name (e.g. +order+, +status+)
  #   current_value: the last value output from this block or, if this is the first time block was
  #     called, +initial_value+.
  #   returns the new accumulated value.
  # Returns
  #   if matched, the value generated by the block if given or an array of +contents+
  #   else, +initial_value+
  def self.recurse_through_metatags(tagstr, *metatags, initial_value: nil, &block)
    to_find = metatags.reduce(nil) { |prior, curr| prior ? "#{prior}|#{curr}" : curr } || "\\S+"
    lb = metatags.reduce(nil) { |prior, curr| prior ? "(?<!#{prior})(?<!#{curr})" : "(?<!#{curr})" }
    la = metatags.reduce(nil) { |prior, curr| prior ? "(?!#{prior})(?!#{curr})" : "(?!#{curr})" }
    # pre = ""
    curr_post = tagstr.to_s.unicode_normalize(:nfc).strip
    # reg = /\A(?<pre>.*?\(\s.*?)(?<body>(?<=\s)(?<tag>#{to_find}):(?:".*?"|.*?(?=\s)))(?<post>.*?\s\).*?)\z/
    # reg = /\A(?<pre>.*?)(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
    # reg = /\A(?<pre>.*?(?=\w*:(?>"[^"]*"|\S*)))(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
    # reg = if lb
    #         /\A(?<pre>(?:.*?(?>\w*:(?:#{lb})(?>"[^"]*"|\S*))?)*?)(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
    #       else
    #         /\A(?<pre>.*?)(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
    #       end
    reg = if lb
            /\A(?<pre>(?:(?>\s*(?>#{la}[^\s:])*)(?>#{lb}:(?>"[^"]*"|\S*))?)*?)(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
          else
            /\A(?<pre>.*?)(?<body>(?<tag>#{to_find}):(?>"[^"]*"|\S*))(?<post>.*)\z/
          end
    while (m = reg.match(curr_post))
      # pre += m[:pre]
      curr_post = m[:post]
      # This should be impossible, that would be matched first and removed
      # # If it's inside another metatag (for some reason), don't touch it and move on.
      # if (pre/m[:pre])[/\w*:"[^"]*\z/] && ((pre/m[:pre]) !~ /\s/ || m[:post].include?('"'))
      #   pre += m[:body]
      #   next
      # end
      if block_given?
        initial_value = block.call(
          pre: m[:pre],
          # pre: pre,
          contents: m[:body],
          post: m[:post],
          tag: m[:tag],
          current_value: initial_value,
        )
      else
        initial_value = [] unless initial_value.respond_to?(:<<)
        initial_value << m[:body]
      end
      # pre = ""
    end
    initial_value
  end

  def self.has_metatag?(tags, *, recurse: true)
    fetch_metatag(tags, *, recurse: recurse).present?
  end

  def self.fetch_metatag(tags, *metatags, recurse: true)
    return nil if tags.blank?

    # tags = recurse ? recurse_through_metatags(tags, *metatags, initial_value: []) : scan(tags) if tags.is_a?(String)
    tags = recurse ? scan_search(tags, hoisted_metatags: metatags) : scan(tags) if tags.is_a?(String)
    tags.find do |tag|
      metatag_name, value = tag.split(":", 2)
      return value if metatags.include?(metatag_name)
    end
  end

  def self.has_tag?(tag_array, *)
    fetch_tags(tag_array, *).any?
  end

  def self.fetch_tags(tag_array, *tags)
    tags.select { |tag| tag_array.include?(tag) }
  end

  def self.ad_tag_string(tag_array)
    if (i = tag_array.index { |v| v == "(" }) && i < (tag_array.index { |v| v == ")" } || -1)
      tag_array = scan_recursive(
        tag_array.join(" "),
        strip_duplicates_at_level: false,
        delimit_groups: false,
        flatten: true,
        strip_prefixes: false,
        sort_at_level: false,
        # NOTE: It would seem to be wise to normalize these tags
        normalize_at_level: false,
      )
    end
    fetch_tags(tag_array, *Danbooru.config.ads_keyword_tags).join(" ")
  end

  private_class_method def self.normalize_single_tag(tag)
    TagAlias.active.where(antecedent_name: Tag.normalize_name(tag))&.first&.consequent_name || tag
  end

  private

  METATAG_SEARCH_TYPE = {
    "-" => :must_not,
    "~" => :should,
  }.freeze

  # TODO: Short-circuit when max tags exceeded?
  def parse_query(query, process_groups: false)
    TagQuery.scan_search(query).each do |token| # rubocop:disable Metrics/BlockLength
      # If there's a group, recurse, correctly increment tag_count, then stop processing this token.
      next if /\A([-~]?)\(\s+(.*?)\s+\)\z/.match(token) do |match|
        group = match[2]
        if process_groups
          # thrown = nil
          begin
            group = TagQuery.new(match[2], free_tags_count: @tag_count + @free_tags_count, resolve_aliases: @resolve_aliases, return_with_count_exceeded: true)
          rescue CountExceededWithDataError => e
            group = e
            # thrown = e
          end
          @tag_count += group.tag_count
        else
          @tag_count += TagQuery.scan_recursive(
            match[2],
            flatten: true,
            delimit_groups: false,
            strip_prefixes: true,
            strip_duplicates_at_level: false,
          ).length
        end
        search_type = METATAG_SEARCH_TYPE.fetch(match[1], :must)
        q[:groups][search_type] ||= []
        q[:groups][search_type] << group
        # raise thrown if thrown
        true
      end
      @tag_count += 1 unless Danbooru.config.is_unlimited_tag?(token)
      metatag_name, g2 = token.split(":", 2)

      # Short-circuit when there is no metatag or the metatag has no value
      if g2.blank?
        add_tag(token)
        next
      end

      # Remove quotes from description:"abc def"
      g2 = g2.delete_prefix('"').delete_suffix('"')

      type = METATAG_SEARCH_TYPE.fetch(metatag_name[0], :must)
      case metatag_name.downcase
      when "user", "-user", "~user"
        add_to_query(type, :uploader_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "user_id", "-user_id", "~user_id"
        add_to_query(type, :uploader_ids) do
          g2.to_i
        end

      when "approver", "-approver", "~approver"
        add_to_query(type, :approver_ids, any_none_key: :approver, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "commenter", "-commenter", "~commenter", "comm", "-comm", "~comm"
        add_to_query(type, :commenter_ids, any_none_key: :commenter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noter", "-noter", "~noter"
        add_to_query(type, :noter_ids, any_none_key: :noter, value: g2) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "noteupdater", "-noteupdater", "~noteupdater"
        add_to_query(type, :note_updater_ids) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "pool", "-pool", "~pool"
        add_to_query(type, :pool_ids, any_none_key: :pool, value: g2) do
          Pool.name_to_id(g2)
        end

      when "set", "-set", "~set"
        add_to_query(type, :set_ids) do
          post_set_id = PostSet.name_to_id(g2)
          post_set = PostSet.find_by(id: post_set_id)

          next 0 unless post_set
          unless post_set.can_view?(CurrentUser.user)
            raise User::PrivilegeError
          end

          post_set_id
        end

      when "fav", "-fav", "~fav", "favoritedby", "-favoritedby", "~favoritedby"
        add_to_query(type, :fav_ids) do
          favuser = User.find_by_name_or_id(g2) # rubocop:disable Rails/DynamicFindBy

          next 0 unless favuser
          if favuser.hide_favorites?
            raise Favorite::HiddenError
          end

          favuser.id
        end

      when "md5"
        q[:md5] = g2.downcase.split(",")[0..99]

      when "rating", "-rating", "~rating"
        add_to_query(type, :rating) { g2[0]&.downcase || "miss" }

      when "locked", "-locked", "~locked"
        add_to_query(type, :locked) do
          case g2.downcase
          when "rating"
            :rating
          when "note", "notes"
            :note
          when "status"
            :status
          end
        end

      when "ratinglocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :rating }
      when "notelocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :note }
      when "statuslocked"
        add_to_query(parse_boolean(g2) ? :must : :must_not, :locked) { :status }

      when "id", "-id", "~id"
        add_to_query(type, :post_id) { ParseValue.range(g2) }

      when "width", "-width", "~width"
        add_to_query(type, :width) { ParseValue.range(g2) }

      when "height", "-height", "~height"
        add_to_query(type, :height) { ParseValue.range(g2) }

      when "mpixels", "-mpixels", "~mpixels"
        add_to_query(type, :mpixels) { ParseValue.range_fudged(g2, :float) }

      when "ratio", "-ratio", "~ratio"
        add_to_query(type, :ratio) { ParseValue.range(g2, :ratio) }

      when "duration", "-duration", "~duration"
        add_to_query(type, :duration) { ParseValue.range(g2, :float) }

      when "score", "-score", "~score"
        add_to_query(type, :score) { ParseValue.range(g2) }

      when "favcount", "-favcount", "~favcount"
        add_to_query(type, :fav_count) { ParseValue.range(g2) }

      when "filesize", "-filesize", "~filesize"
        add_to_query(type, :filesize) { ParseValue.range_fudged(g2, :filesize) }

      when "change", "-change", "~change"
        add_to_query(type, :change_seq) { ParseValue.range(g2) }

      when "source", "-source", "~source"
        add_to_query(type, :sources, any_none_key: :source, value: g2, wildcard: true) do
          "#{g2}*"
        end

      when "date", "-date", "~date"
        add_to_query(type, :date) { ParseValue.date_range(g2) }

      when "age", "-age", "~age"
        add_to_query(type, :age) { ParseValue.invert_range(ParseValue.range(g2, :age)) }

      when "tagcount", "-tagcount", "~tagcount"
        add_to_query(type, :post_tag_count) { ParseValue.range(g2) }

      when /[-~]?(#{TagCategory::SHORT_NAME_REGEX})tags/
        add_to_query(type, :"#{TagCategory::SHORT_NAME_MAPPING[$1]}_tag_count") { ParseValue.range(g2) }

      when "parent", "-parent", "~parent"
        add_to_query(type, :parent_ids, any_none_key: :parent, value: g2) do
          g2.to_i
        end

      when "child"
        q[:child] = g2.downcase

      when "randseed"
        q[:random_seed] = g2.to_i

      when "order"
        q[:order] = g2.downcase

      when "limit"
        # Do nothing. The controller takes care of it.

      when "status"
        q[:status] = g2.downcase

      when "-status"
        q[:status_must_not] = g2.downcase

      when "filetype", "-filetype", "~filetype", "type", "-type", "~type"
        add_to_query(type, :filetype) { g2.downcase }

      when "description", "-description", "~description"
        add_to_query(type, :description) { g2 }

      when "note", "-note", "~note"
        add_to_query(type, :note) { g2 }

      when "delreason", "-delreason", "~delreason"
        q[:status] ||= "any"
        add_to_query(type, :delreason, wildcard: true) { g2 }

      when "deletedby", "-deletedby", "~deletedby"
        q[:status] ||= "any"
        add_to_query(type, :deleter) do
          user_id = User.name_or_id_to_id(g2)
          id_or_invalid(user_id)
        end

      when "upvote", "-upvote", "~upvote", "votedup", "-votedup", "~votedup"
        add_to_query(type, :upvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "downvote", "-downvote", "~downvote", "voteddown", "-voteddown", "~voteddown"
        add_to_query(type, :downvote) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when "voted", "-voted", "~voted"
        add_to_query(type, :voted) do
          if CurrentUser.is_moderator?
            user_id = User.name_or_id_to_id(g2)
          elsif CurrentUser.is_member?
            user_id = CurrentUser.id
          end
          id_or_invalid(user_id)
        end

      when *COUNT_METATAGS
        q[metatag_name.downcase.to_sym] = ParseValue.range(g2)

      when *BOOLEAN_METATAGS
        q[metatag_name.downcase.to_sym] = parse_boolean(g2)

      else
        add_tag(token)
      end
    end

    normalize_tags if resolve_aliases
  end

  def add_tag(tag)
    tag = tag.downcase
    if tag.start_with?("-") && tag.length > 1
      if tag.include?("*")
        q[:tags][:must_not] += pull_wildcard_tags(tag.delete_prefix("-"))
      else
        q[:tags][:must_not] << tag.delete_prefix("-")
      end

    elsif tag[0] == "~" && tag.length > 1
      q[:tags][:should] << tag.delete_prefix("~")

    elsif tag.include?("*")
      q[:tags][:should] += pull_wildcard_tags(tag)

    else
      q[:tags][:must] << tag.downcase
    end
  end

  def add_to_query(type, key, any_none_key: nil, value: nil, wildcard: false, &)
    if any_none_key && (value.downcase == "none" || value.downcase == "any")
      add_any_none_to_query(type, value.downcase, any_none_key)
      return
    end

    value = yield
    value = value.squeeze("*") if wildcard # Collapse runs of wildcards for efficiency

    case type
    when :must
      q[key] ||= []
      q[key] << value
    when :must_not
      q[:"#{key}_must_not"] ||= []
      q[:"#{key}_must_not"] << value
    when :should
      q[:"#{key}_should"] ||= []
      q[:"#{key}_should"] << value
    end
  end

  def add_any_none_to_query(type, value, key)
    case type
    when :must
      q[key] = value
    when :must_not
      if value == "none"
        q[key] = "any"
      else
        q[key] = "none"
      end
    when :should
      q[:"#{key}_should"] = value
    end
  end

  def pull_wildcard_tags(tag)
    matches = Tag.name_matches(tag).limit(Danbooru.config.tag_query_limit).order("post_count DESC").pluck(:name)
    matches = ["~~not_found~~"] if matches.empty?
    matches
  end

  def normalize_tags
    q[:tags][:must] = TagAlias.to_aliased(q[:tags][:must])
    q[:tags][:must_not] = TagAlias.to_aliased(q[:tags][:must_not])
    q[:tags][:should] = TagAlias.to_aliased(q[:tags][:should])
  end

  def parse_boolean(value)
    value&.downcase == "true"
  end

  def id_or_invalid(val)
    return -1 if val.blank?
    val
  end
end
