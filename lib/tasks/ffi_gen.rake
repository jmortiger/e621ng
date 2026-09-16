# frozen_string_literal: true

require "ffi/tools/generator_task"

# FFI::Generator::Task.new ["app/logical/tag_tokenizer.rb"], cflags: "-I/usr/local/mylibrary"
# # FFI::Generator::Task.new ["tag_tokenizer.rb"], cflags: "-I/usr/local/mylibrary"
header_path = "./rust_parser"
FFI::Generator::Task.new ["app/logical/tag_tokenizer.rb"], cflags: "-I#{header_path}", cppflags: "-I#{header_path}"
# FFI::Generator::Task.new ["tag_tokenizer.rb"], cflags: "-I./rust_parser"
desc "generate FFI structs"
# task ffi_generate: ["app/logical/tag_tokenizer.rb"]
# # task ffi_generate: ["tag_tokenizer.rb"]
task ffi_generate: ["app/logical/tag_tokenizer.rb"]
# task ffi_generate: ["tag_tokenizer.rb"]
task ffi_clean: :environment do
  rm_f "app/logical/tag_tokenizer.rb"
  # rm_f "tag_tokenizer.rb"
end
file "app/logical/tag_tokenizer.rb.ffi" => ["ffi_clean"] do |t|
# file "tag_tokenizer.rb.ffi" do |t|
        puts "Generating app/logical/tag_tokenizer.rb..." if Rake.application.options.trace
        # puts "Generating tag_tokenizer.rb..." if Rake.application.options.trace

        FFI::Generator.new "app/logical/tag_tokenizer.rb.ffi", "app/logical/tag_tokenizer.rb", cflags: "-I#{header_path}", cppflags: "-I#{header_path}"
        # FFI::Generator.new "tag_tokenizer.rb.ffi", "tag_tokenizer.rb"
      end
