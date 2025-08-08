# frozen_string_literal: true

module Danbooru
  module HasBitFlags
    extend ActiveSupport::Concern

    module ClassMethods
      # Creates methods to modify & access the state of the given field containing the given bit flags.
      # ### Parameters
      # * `attributes` {`String[]`}: The names of the bit flags
      # * `:field` {`Symbol` | `String`} [`:bit_flags`]: The name of the field containing the bit flags.
      # * `:index_getters` [`nil`]: Should the `flag_index_for` singleton method be defined?
      # * `:readonly` [`nil`]: Is the bit flag field readonly?
      # * `:active_names` [`nil`]: Should the `active_#{field}` getters & setters be defined?
      # * `:calculate_bit_flags` [`nil`]: Should the `calculate_#{field}_value` singleton method be defined?
      # * `:skip_statics` [`nil`]: If already manually created, don't create static methods.
      # * `:composed` [`nil`]: Should this be made of multiple bit fields; 1 that's editable, & another that is composed with it by a logical AND/OR/XOR?
      #    * `:main` {`String`}: The main, editable bit field
      #    * ***One*** of the following:
      #       * `:xor` {`String`}
      #       * `:and` {`String`}: Can't always set resultant flag
      #       * `:or` {`String`}: Can't always clear resultant flag
      # * `:wrapper_prefix` [`nil`] {`String`}: the prefix to apply to each attribute to get the wrapper method name.
      # * `:wrapper_suffix` [`nil`] {`String`}: the suffix to apply to each attribute to get the wrapper method name.
      # * `:wrappers` [`nil`] {`Hash<String, Proc | nil>`}: methods to wrap attribute getter/setters in; can be used to add additional logic to their outputs.
      # #### Block
      # If defined, used instead of `:wrappers` to create wrapper methods.
      # * `attribute` {`String`}: the attribute name we're defining
      #
      # Returns a 2-element array w/ the getter & the setter respectively.
      #
      # NOTE: the ordering of attributes has to be fixed#
      # new attributes should be appended to the end.
      def has_bit_flags(attributes, **options)
        field = options[:field] || options[:composed]&.send(:[], :main) || :bit_flags
        if options[:composed]
          if (other_field = options[:composed][:xor])
            op = "^"
          elsif (other_field = options[:composed][:and])
            op = "&"
          elsif (other_field = options[:composed][:or])
            op = "|"
          else
            raise StandardError "No valid other field"
          end

        end

        define_static_bit_field_methods(attributes, **options) unless options[:skip_statics]

        attributes.each.with_index do |attribute, i|
          # NOTE: Will this be the right size? Could screw up clearing a flag if not.
          bit_flag = 1 << i

          define_method("set_#{attribute}") { send("#{field}=", send(field) | bit_flag) }
          define_method("clear_#{attribute}") { send("#{field}=", send(field) & ~bit_flag) }
          if op == "^"
            define_method(attribute) { ((send(field) & bit_flag) ^ (send(other_field) & bit_flag)) > 0 }
            unless options[:readonly]
              define_method("#{attribute}=") do |val|
                send("#{
                    if val.to_s =~ /t|1|y/
                      (send(other_field) & bit_flag) == bit_flag ? 'clear' : 'set' # rubocop:disable Metrics/BlockNesting
                    else # Set both or clear both
                      (send(other_field) & bit_flag) == bit_flag ? 'set' : 'clear' # rubocop:disable Metrics/BlockNesting
                    end
                  }_#{attribute}")
                # val = (val.to_s =~ /t|1|y/)
                # send("#{
                #     (val && (send(other_field) & bit_flag) == bit_flag) || (!val && (send(other_field) & bit_flag) != bit_flag) ? 'clear' : 'set'
                #   }_#{attribute}")
              end
            end
          else
            define_method(attribute) { send(field) & bit_flag > 0 }
            define_method("#{attribute}=") { |v| send("#{v.to_s =~ /t|1|y/ ? 'set' : 'clear'}_#{attribute}") } unless options[:readonly]
          end
          send(:alias_method, :"#{attribute}?", attribute.to_sym)
        end

        if options[:active_names]
          # Returns the currently active flags by name
          define_method("active_#{field}") { attributes.select { |e| send("#{e}?") } }

          unless options[:readonly]
            # Sets the currently active flags by name
            define_method("active_#{field}=") do |vals|
              vals.each { |e| send("#{e}=", true) }
              (attributes - vals).each { |e| send("#{e}=", false) }
            end

            # Sets the specified flags to active by name
            define_method("active_#{field}|=") { |vals| vals.each { |e| send("#{e}=", true) } }
          end
        end
      end

      def define_static_bit_field_methods(attributes, **options)
        field = options[:field] || options[:composed]&.send(:[], :main) || :bit_flags

        if options[:index_getters]
          define_singleton_method("flag_index_for") do |key|
            # IDEA: Would a hash be better?
            index = attributes.index(key)
            raise IndexError if index.nil?
            index
          end
        end

        define_singleton_method("flag_value_for") do |key|
          # IDEA: Would a hash be better?
          index = attributes.index(key)
          raise IndexError if index.nil?
          1 << index
        end

        attributes.each.with_index do |attribute, i|
          bit_flag = 1 << i

          define_singleton_method("#{attribute}_flag_index") { i }
          define_singleton_method("#{attribute}_flag_bit") { bit_flag }
          define_singleton_method("has_#{attribute}_set?") { |v| (bit_flag & v) > 0 }
        end

        if options[:active_names]
          # Returns the currently active flags by name
          define_method("active_#{field}") { attributes.select { |e| send("#{e}?") } }

          unless options[:readonly]
            # Sets the currently active flags by name
            define_method("active_#{field}=") do |vals|
              vals.each { |e| send("#{e}=", true) }
              (attributes - vals).each { |e| send("#{e}=", false) }
            end

            # Sets the specified flags to active by name
            define_method("active_#{field}|=") { |vals| vals.each { |e| send("#{e}=", true) } }
          end
        end

        if options[:calculate_bit_flags]
          define_singleton_method("calculate_#{field}_value") do |vals|
            ret_val = 0
            attributes.each.with_index do |attribute, i|
              ret_val |= 1 << i if vals.include?(attribute)
            end
            ret_val
          end
        end
      end
    end
  end
end
