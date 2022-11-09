# frozen_string_literal: true
module Stupidedi
  using Refinements
  module Writer
    autoload :Claredi,  "stupidedi/writer/claredi"
    autoload :Default,  "stupidedi/writer/default"

    class Json
      def initialize(node)
        @node = node
      end

      # @return [Hash]
      def write(out = Hash.new { |k, v| self[k] = v })
        build(@node, out)
        out
      end

      private

      def resolve_traverser(node)
        case
        when node.transmission?
           Transmission
        when node.interchange?
          Interchange
        when node.segment?
          Segment
        when node.loop?
          Loop
        when node.element?
          Element
        when node.functional_group?
          FunctionalGroup
        when node.transaction_set?
          TransactionSet
        when node.table?
          Table
        else
          NullNode
        end.new(node)
      end

      def build(node, out)
        traverser = resolve_traverser(node)

        traverser.reduce(out) do |children, memo = {}|
          build(children, memo)
        end

        out
      end
    end

    class Transmission
        attr_reader :node

        def_delegators :node, :children

        def initialize(node)
          @node = node
        end

        def reduce(memo, &block)
          if single_child?
            block.call(child, memo)
          else
            children.map { |c| block.call(c, memo) }
          end
        end

        def single_child?
          children.size == 1
        end

        def child
          @child ||= children.first
        end
      end
      
  end
end
