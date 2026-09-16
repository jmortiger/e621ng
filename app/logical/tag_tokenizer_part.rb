# frozen_string_literal: true

require "ffi"

# This is used to allow `app/logical/tag_tokenizer.rb.ffi` to be generated; should not be used in production.
module TagTokenizerPart
  extend FFI::Library
  ffi_lib "/app/librust_parser.so"
  TokenType = enum(
    :none,
    :tag,
    :metatag,
    :groupopen,
    :groupclose,
    :group, 0b1000,
    :root, 0b10000,
  )
  Prefix = enum(
    :prefixnone,
    :negated,
    :optional,
  )

  # @@@
  # constants do |c|
  #   c.include "rust_parser.h"
  #   c.const :LIB_VER_MAJOR
  #   c.const :LIB_VER_MINOR
  # end
  # @@@

  class GenericTokenSlice < FFI::Struct
  #   @@@
  #   struct do |s|
  #     s.name 'struct GenericTokenSlice'
  #     s.include "rust_parser.h"
  #     s.field :length, :uintptr_t
  #     s.field :slice, s.GenericTokenFfi.ptr
  #   end
  #   @@@
  end

  class GenericTokenFfi < FFI::Struct
  #   @@@
  #   struct do |s|
  #     s.name 'struct GenericTokenFfi'
  #     s.include "rust_parser.h"
  #     s.field :starting_index, :uint32
  #     s.field :length, :uint32
  #     s.field :token_type, TokenType
  #     s.field :prefix, Prefix
  #     s.field :token_index, :uint32
  #     s.field :sub_tokens, GenericTokenSlice.ptr
  #   end
  #   @@@
  end
  
end
