# frozen_string_literal: true

require "ffi"

module Tokenizer
  extend FFI::Library
  ffi_lib "/app/librust_parser.so"
  # TokenType = enum(:none, :tag, :metatag, :groupopen, :groupclose, :group, 0b1000, :root, 0b10000)
  TokenType = enum(FFI::Type::Builtin::UINT32, :TokenType, [
    :none,
    :tag,
    :metatag,
    :groupopen,
    :groupclose,
    :group, 0b1000,
    :root, 0b10000,
  ])
  # Prefix = enum(:prefixnone, :negated, :optional)
  Prefix = enum(FFI::Type::Builtin::UINT32, :Prefix, %i[
    prefixnone
    negated
    optional
  ])

  class GenericTokenSlice < FFI::Struct
    layout(
      :slice, :pointer,
      :length, :uintptr_t
    )
    # IDEA: Look into FFI::Pointer.read_array_of_type?
    def to_a
      return [] unless self[:length] > 0
      (0...self[:length]).map do |i|
        GenericTokenNodeFinal.new(self[:slice] + (i * size))
      end
    end
  end
  # module GenericTokenSliceLayout
  #   def self.included(base)
  #     base.class_eval do
  #       layout(
  #         :slice, :pointer,
  #         :length, :uintptr_t
  #       )
  #       # IDEA: Look into FFI::Pointer.read_array_of_type?
  #       def to_a
  #         return [] unless self[:length] > 0
  #         (0...self[:length]).map do |i|
  #           GenericTokenNodeFinal.new(self[:slice] + (i * size))
  #         end
  #       end
  #     end
  #   end
  # end

  module GenericTokenNodeLayout
    def self.included(base)
      base.class_eval do
        layout(
          :starting_index, :uint32,
          :length, :uint32,
          :token_type, TokenType,
          :prefix, Prefix,
          :token_index, :uint32,
          :sub_tokens, GenericTokenSlice
        )
      end
    end
  end

  class GenericTokenNodeFinal < FFI::ManagedStruct
    include GenericTokenNodeLayout

    private_class_method def self.add_root_pointer(ptr)
      @@root_nodes ||= Set.new
      @@root_nodes.add(ptr)
    end

    def self.release(ptr)
      Tokenizer.free_token(ptr) if @@root_nodes.include?(ptr)
    end

    # * `query`
    # * `resolve_aliases` [`true`]
    # * `free_tags_count` [`0`]
    # * `error_on_depth_exceeded` [`false`]
    # * `depth` [`0`]
    def initialize(
      ptr: nil,
      query: nil,
      availible_tokens: 0,
      error_on_depth_exceeded: false,
      depth: 0
    )
      if ptr
        super(ptr)
        return
      end

      unless query
        raise ArgumentError, "Need either an address or a query"
      end

      super(Tokenizer.tokenize_ffi_raw(
        query,
        availible_tokens,
        error_on_depth_exceeded,
        depth,
      ))
      @is_root = true
    end

    def to_h(query = nil)
      {
        starting_index: self[:starting_index],
        token_index: self[:token_index],
        length: self[:length],
        token_type: self[:token_type],
        prefix: self[:prefix],
        sub_tokens: self[:sub_tokens],
      }.merge(query.present? ? { contents: get_string(query) } : {})
    end

    def get_string(query)
      query[self[:starting_index], self[:length]]
    end

    def print_inspect_string(query, level = 0)
      prefix = ""
      if level > 0
        (0...level).each { prefix += "  " }
      end
      puts "#{prefix}GenericTokenNodeFinal #{self[:token_index]} #{self[:starting_index]}-#{self[:starting_index] + self[:length]}: Type=#{self[:token_type]}, Prefix=#{self[:prefix]} \"#{get_string(query)}\" (#{self[:sub_tokens][:length]} subtokens)\n"
      if self[:sub_tokens][:length] > 0
        count = self[:sub_tokens][:length]
        if level > 10
          puts "OVER 10 LEVELS DEEP (#{level}); NOT PRINTING ANY OF THE #{count} SUB TOKENS"
          return
        end
        if count > 100
          puts "OVER 100 SUB TOKENS (#{count}); PRINTING FIRST 100"
          count = 100
        end
        level += 1
        (0...count).map do |i|
          GenericTokenNodeFinal.new(self[:sub_tokens][:slice] + (i * size)).print_inspect_string(query, level)
        end
      end
    end
  end

  attach_function(:tokenize_ffi, :tokenize_ffi, %i[string uint32 uint32 bool bool bool], GenericTokenNodeFinal.ptr)
  attach_function(:tokenize_ffi_raw, :tokenize_ffi, %i[string uint32 uint32 bool bool bool], :pointer)
  attach_function(:free_token, :free_token, [:pointer], :void)
  attach_function(:check_token, :check_token, [GenericTokenNodeFinal.ptr, :string], :string)
  attach_function(:free_token_string, :free_token_string, [:string], :void)
  def self.simple_test(try_arr: false, inspect_str: true)
    query = "( ~male ~female ~intersex ~ambiguous_gender ) ( ~feral ~humanoid ~anthro ~taur ) -( ~male_feral ~male_humanoid ~male_anthro ~male_taur ~female_feral ~female_humanoid ~female_anthro ~female_taur ~intersex_feral ~intersex_humanoid ~intersex_anthro~intersex_taur ~ambiguous_feral ~ambiguous_humanoid ~ambiguous_anthro ~ambiguous_taur )"
    t = Tokenizer.tokenize_ffi(query, 0, 40, false, false, true)
    puts "Incorrect starting_index (#{t[:starting_index]})" unless t[:starting_index] == 0
    puts "Incorrect token_index (#{t[:token_index]})" unless t[:token_index] == 0
    puts "Incorrect length (#{t[:length]}, expected #{query.length})" unless t[:length] == query.length
    puts "Incorrect token_type (#{t[:token_type]})" unless t[:token_type] == :none
    puts "Incorrect prefix (#{t[:prefix]})" unless t[:prefix] == :prefixnone
    puts "Incorrect t[:sub_tokens][:length] (#{t[:sub_tokens][:length]})" unless t[:sub_tokens][:length] == 3
    puts "Incorrect substring (#{t.get_string(query)})" unless t.get_string(query) == query
    if try_arr
      a = t[:sub_tokens].to_a
      puts "As arr: #{a}"
      elem = a[0]
      subquery = "( ~male ~female ~intersex ~ambiguous_gender )"
      puts "For element 0"
      puts "Incorrect starting_index (#{elem[:starting_index]})" unless elem[:starting_index] == 0
      puts "Incorrect token_index (#{elem[:token_index]})" unless elem[:token_index] == 0
      puts "Incorrect length (#{elem[:length]}, expected #{subquery.length})" unless elem[:length] == subquery.length
      puts "Incorrect token_type (#{elem[:token_type]})" unless elem[:token_type] == :group
      puts "Incorrect prefix (#{elem[:prefix]})" unless elem[:prefix] == :prefixnone
      puts "Incorrect elem[:sub_tokens][:length] (#{elem[:sub_tokens][:length]})" unless elem[:sub_tokens][:length] == 6
      puts "Incorrect substring (#{elem.get_string(query)})" unless elem.get_string(query) == subquery
      puts elem.to_h(query)
      puts "Children: #{elem[:sub_tokens].to_a.map { |e| e.to_h(query) }}"
      # a.each_index do |elem, i|
      #   puts "Incorrect starting_index (#{elem[:starting_index]})" unless elem[:starting_index] == 0
      #   puts "Incorrect token_index (#{elem[:token_index]})" unless elem[:token_index] == 0
      #   puts "Incorrect length (#{elem[:length]}, expected #{query.length})" unless elem[:length] == query.length
      #   puts "Incorrect token_type (#{elem[:token_type]})" unless elem[:token_type] == :none # 0 # Tokenizer::TokenType[:]
      #   puts "Incorrect prefix (#{elem[:prefix]})" unless elem[:prefix] == :prefixnone # Tokenizer::Prefix[:prefixnone]
      #   puts "Incorrect elem[:sub_tokens][:length] (#{elem[:sub_tokens][:length]})" unless elem[:sub_tokens][:length] == 3
      # end
    end
    if inspect_str
      puts "Inspecting..."
      t.print_inspect_string(query)
    end
    # Tokenizer.free_token(t)
  rescue => e
    puts "Threw; #{e}"
    # begin
    #   Tokenizer.free_token(t)
    # end
  ensure
    # Tokenizer.free_token(t)
    rust_analysis = Tokenizer.check_token(t, query)
    puts "Analysis from Rust:\n#{rust_analysis[0..]}"
    Tokenizer.free_token_string(rust_analysis)
  end

  
end
