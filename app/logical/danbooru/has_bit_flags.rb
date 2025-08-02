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
      # * `:composed` [`nil`]: Should this be made of multiple bit fields; 1 that's editable, & another that is composed with it by a logical AND/OR/XOR?
      #    * `:main` {`String`}: The main, editable bit field
      #    * ***One*** of the following:
      #       * `:xor` {`String`}
      #       * `:and` {`String`}
      #       * `:or` {`String`}
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

          define_method("set_#{attribute}") { send("#{field}=", send(field) | bit_flag) }
          define_method("clear_#{attribute}") { send("#{field}=", send(field) & ~bit_flag) }
          getter, setter = case op
                           when "^"
                             [
                               -> do
                                 ((send(field) & bit_flag) ^ (send(other_field) & bit_flag)) > 0
                               end,
                               ->(val) do
                                 send(
                                   "#{field}=",
                                   if val.to_s =~ /t|1|y/
                                     if (send(other_field) & bit_flag) == bit_flag
                                       send("clear_#{attribute}")
                                     else
                                       send("set_#{attribute}")
                                     end
                                   elsif (send(other_field) & bit_flag) != bit_flag
                                     send("clear_#{attribute}")
                                   else
                                     send("set_#{attribute}")
                                   end,
                                 )
                               end,
                             ]
                             #  when "|"
                             #    [
                             #      ->() do
                             #       ((send(field) & bit_flag) | (send(other_field) & bit_flag)) > 0
                             #      end,
                             #      ->(val) do
                             #        if val.to_s =~ /t|1|y/
                             #          send("#{field}=", send(field) | bit_flag)
                             #        else
                             #          send("#{field}=", send(field) & ~bit_flag)
                             #        end
                             #      end,
                             #    ]
                             #  when "&"
                             #    [
                             #      ->() do
                             #       ((send(field) & bit_flag) & (send(other_field) & bit_flag)) > 0
                             #      end,
                             #      ->(val) do
                             #        if val.to_s =~ /t|1|y/
                             #          send("#{field}=", send(field) | bit_flag)
                             #        else
                             #          send("#{field}=", send(field) & ~bit_flag)
                             #        end
                             #      end,
                             #    ]
                           else
                             [
                               -> do
                                 send(field) & bit_flag > 0
                               end,
                               ->(val) do
                                 if val.to_s =~ /t|1|y/
                                   send("#{field}=", send(field) | bit_flag)
                                 else
                                   send("#{field}=", send(field) & ~bit_flag)
                                 end
                               end,
                             ]
                           end
          # getter = case op
          #          when "^"
          #            ->() do
          #              ((send(field) & bit_flag) ^ (send(other_field) & bit_flag)) > 0
          #            end
          #          when "|"
          #            ->() do
          #              ((send(field) & bit_flag) | (send(other_field) & bit_flag)) > 0
          #            end
          #          when "&"
          #            ->() do
          #              ((send(field) & bit_flag) & (send(other_field) & bit_flag)) > 0
          #            end
          #          else
          #            ->() do
          #              send(field) & bit_flag > 0
          #            end
          #          end
          define_method(attribute, getter)

          send(:alias_method, :"#{attribute}?", attribute.to_sym)

          next if options[:readonly]

          define_method("#{attribute}=", setter)
          # define_method("#{attribute}=") do |val|
          #   if val.to_s =~ /t|1|y/
          #     send("#{field}=", send(field) | bit_flag)
          #   else
          #     send("#{field}=", send(field) & ~bit_flag)
          #   end
          # end
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
