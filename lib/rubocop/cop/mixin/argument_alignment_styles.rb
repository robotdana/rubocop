# frozen_string_literal: true

module RuboCop
  module Cop
    # Common functionality for checking hash alignment.
    module ArgumentAlignmentStyles
      # Handles calculation of deltas when the enforced style is 'key'.
      class KeyAlignment
        def checkable_layout?(_node)
          true
        end

        def deltas_for_first_pair(left_pos, first_pair, _node)
          {
            key: key_delta_for_first_pair(left_pos, first_pair),
            separator: separator_delta(first_pair),
            value: value_delta(first_pair)
          }
        end

        def deltas(left_pos, first_pair, current_pair)
          if Util.begins_its_line?(current_pair.source_range)
            key_delta = key_delta(left_pos, first_pair, current_pair)
            separator_delta = separator_delta(current_pair)
            value_delta = value_delta(current_pair)

            { key: key_delta, separator: separator_delta, value: value_delta }
          else
            {}
          end
        end

        private

        def key_delta_for_first_pair(left_pos, first_pair)
          if left_pos && Util.begins_its_line?(first_pair.source_range)
            left_pos - first_pair.key.loc.column
          else
            0
          end
        end

        def key_delta(left_pos, first_pair, current_pair)
          if left_pos
            left_pos - current_pair.key.loc.column
          else
            first_pair.key_delta(current_pair)
          end
        end

        def separator_delta(pair)
          if pair.hash_rocket?
            correct_separator_column = pair.key.loc.expression.end.column + 1
            actual_separator_column = pair.loc.operator.column

            correct_separator_column - actual_separator_column
          else
            0
          end
        end

        def value_delta(pair)
          return 0 if pair.kwsplat_type? || pair.value_on_new_line?

          correct_value_column = pair.loc.operator.end.column + 1
          actual_value_column = pair.value.loc.column

          correct_value_column - actual_value_column
        end
      end

      # Common functionality for checking alignment of hash values.
      module ValueAlignment
        def checkable_layout?(node)
          !node.pairs_on_same_line? && !node.mixed_delimiters?
        end

        def deltas(left_node, first_pair, current_pair)
          key_delta = key_delta(first_pair, current_pair)
          separator_delta = separator_delta(first_pair, current_pair, key_delta)
          value_delta = value_delta(first_pair, current_pair) - key_delta - separator_delta

          { key: key_delta, separator: separator_delta, value: value_delta }
        end

        private

        def separator_delta(first_pair, current_pair, key_delta)
          if current_pair.hash_rocket?
            hash_rocket_delta(first_pair, current_pair) - key_delta
          else
            0
          end
        end
      end

      # Handles calculation of deltas when the enforced style is 'table'.
      class TableAlignment
        include ValueAlignment

        def initialize
          self.max_key_width = 0
        end

        def deltas_for_first_pair(left_node, first_pair, node)
          self.max_key_width = node.keys.map { |key| key.source.length }.max

          separator_delta = separator_delta(first_pair, first_pair, 0)
          {
            separator: separator_delta,
            value: value_delta(first_pair, first_pair) - separator_delta
          }
        end

        private

        attr_accessor :max_key_width

        def key_delta(first_pair, current_pair)
          first_pair.key_delta(current_pair)
        end

        def hash_rocket_delta(first_pair, current_pair)
          first_pair.loc.column + max_key_width + 1 - current_pair.loc.operator.column
        end

        def value_delta(first_pair, current_pair)
          return 0 if current_pair.kwsplat_type?

          correct_value_column = first_pair.key.loc.column +
                                 current_pair.delimiter(true).length +
                                 max_key_width
          correct_value_column - current_pair.value.loc.column
        end
      end

      # Handles calculation of deltas when the enforced style is 'separator'.
      class SeparatorAlignment
        include ValueAlignment

        def deltas_for_first_pair(*_nodes)
          {}
        end

        private

        def key_delta(first_pair, current_pair)
          first_pair.key_delta(current_pair, :right)
        end

        def hash_rocket_delta(first_pair, current_pair)
          first_pair.delimiter_delta(current_pair)
        end

        def value_delta(first_pair, current_pair)
          first_pair.value_delta(current_pair)
        end
      end
    end
  end
end
