require "active_support"
require "active_support/core_ext"

module Workflows
  module Types
    include Dry.Types

    class Stage < Dry::Struct
      include Comparable
      attribute :name, Types::Strict::Symbol
      attribute? :action,  Types::Strict::Symbol
      attribute :approval,  Types::Strict::Bool.default(false)

      def initialize(data)
        if data.key?(:action)
          if [:approve, :reject].include?(data[:action])
            raise DefinitionError, "Action name cannot be :approve or :reject"
          end
        end

        super
      end
      def self.parse(data)
        name = data[:name].to_sym
        new_attribs = data.merge({name: })
        new_attribs[:action] = data[:action].to_sym if data.key?(:action)
        self.new(new_attribs)
      end

      def <=>(other)
        [name, action, approval] <=> [name, action, approval]
      end
    end

    class Transition < Dry::Struct
      include Comparable
      attribute :from, Types::Strict::Symbol
      attribute :to, Types::Strict::Symbol

      def self.parse(data)
        self.new(data)
      end

      def <=>(other)
        [from, to] <=> [other.from, other.to]
      end
    end

    class WorkflowState < Dry::Struct
      include Comparable
      attribute :stage, Types::Strict::Symbol
      attribute :state, Types::Strict::Symbol
      attribute? :action,  Types::Strict::Symbol
      attribute :approval_state, Types::Strict::Symbol.default(:none)
      attribute :allowed_transitions, Types::Array.of(Workflows::Types::Transition).default { [] }
      attribute :allowed_actions, Types::Array.of(Types::Strict::Symbol).default { [] }

      def self.parse(data)
        self.new(data)
      end

      def change(new_attributes)
        attributes = self.attributes.merge(new_attributes)
        self.class.new(attributes)
      end

      def <=>(other)
        [stage, state] <=> [other.stage, other.state]
      end
    end
  end
end
