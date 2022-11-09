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

    class Interchange
      attr_reader :node

      def_delegators :node, :children

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        memo[key] = children.map do |c|
          block.call(c)
        end
      end

      def key
        :interchanges
      end
    end

    class Segment
      attr_reader :node

      def_delegators :node, :repeated?, :children, :id

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        return memo if node.empty?

        memo[key] = if single_child?
           block.call(child)
        else
          children.map do |c|
            block.call(c)
          end
        end
      end

      def key
        id
      end

      def single_child?
        children.size == 1
      end

      def child
        @child ||= children.first
      end
    end

    class Loop
      attr_reader :node

      def_delegators :node, :definition, :children
      def_delegators :definition, :id

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        memo[key] = children.map do |c|
          block.call(c)
        end
      end

      def key
        id
      end
    end

    class Element
      attr_reader :node

      def_delegators :node, :definition, :simple?, :composite?, :repeated?, :children
      def_delegators :definition, :code_list, :id, :name

      def initialize(node)
        @node = node
      end

      def reduce(memo, *)
        memo[key] = {
          name: name,
          value: value,
          type: type
        }
      end

      def type
        case
        when node.composite?
          :composite
        when node.repeated?
          :repeated
        else
          :simple
        end
      end

      def key
        id
      end

      class SimpleElement
        attr_reader :node

        def_delegators :node, :definition
        def_delegators :definition, :code_list

        def initialize(node)
          @node = node
        end

        def call(*)
          {
            raw: value, # leaf node
            description: description
          }
        end

        def description
          if definition.respond_to?(:code_list)
            if code_list.try(:internal?)
              code_list.try(:at, value)
            else
              value
            end
          end
        end

        def value
          node.to_s.strip
        end
      end

      class RepeatedElement
        attr_reader :node

        def initialize(node)
          @node = node
        end

        def call(&block)
          node.children.map do |c|
            block.call(c)
          end
        end
      end

      class CompositeElement
        attr_reader :node

        def initialize(node)
          @node = node
        end

        def call(&block)
          node.children.map do |c|
            block.call(c)
          end
        end
      end

      class ElementReducer
        attr_reader :node

        def initialize(node)
          @node = node
        end

        def reducer
          case
          when node.simple?
            SimpleElement
          when node.repeated?
            RepeatedElement
          when node.composite?
            CompositeElement
          else
            SimpleElement
          end.new(node)
        end

        def build
          reducer.call do |children|
            self.class.new(children).build
          end
        end
      end

      def value
        ElementReducer.new(node).build
      end
    end

    class FunctionalGroup
      attr_reader :node

      def_delegators :node, :children

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        memo[key] = children.map do |c|
          block.call(c)
        end
      end

      def key
        :functional_groups
      end
    end

    class TransactionSet
      attr_reader :node

      def_delegators :node, :children

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        memo[key] = children.map do |c|
          block.call(c)
        end
      end

      def key
        :transactions
      end
    end

    class Table
      attr_reader :node

      def_delegators :node, :repeated?, :definition, :children
      def_delegators :node, :definition
      def_delegators :definition, :id

      def initialize(node)
        @node = node
      end

      def reduce(memo, &block)
        memo[key] = children.map do |c|
          block.call(c)
        end
      end

      def key
        id
      end
    end

    class NullNode
      def initialize(*)
      end

      def reduce(memo, *)
        # do nothing
        memo
      end
    end

  end
end
