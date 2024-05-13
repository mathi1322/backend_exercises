require "active_support"
require "active_support/core_ext"

module Workflows
  module Types
    include Dry.Types

    class Stage < Dry::Struct
      include Comparable
      attribute :name, Types::Strict::Symbol

      def self.parse(data)
        name = data[:name].to_sym
        self.new(data.merge(name:))
      end

      def <=>(other)
        [name] <=> [name]
      end
    end

    class Transition < Dry::Struct
      include Comparable
      attribute :from, Types::Strict::Symbol
      attribute :to, Types::Strict::Symbol
      attribute? :action,  Types::Strict::Symbol
      attribute? :approve_action,  Types::Strict::Symbol

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
