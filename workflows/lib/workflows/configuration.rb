# frozen_string_literal: true

module Workflows
  include Dry.Types
  module Configuration

    def self.included(base)
      base.class_eval do
        attribute :transitions, Types::Array.of(Workflows::Types::Transition).default { [] }
        attribute? :conclusion, Types::Strict::Symbol
        attribute? :beginning, Types::Strict::Symbol

        def self.parse(data)
          transitions = data[:transitions].map { |td|  Workflows::Types::Transition.parse(td) }
          hsh = data.merge(transitions:)
          hsh[:conclusion] = hsh[:conclusion].to_sym if(hsh.key?(:conclusion))
          hsh[:beginning] = hsh[:beginning].to_sym if(hsh.key?(:beginning))
          self.new(hsh)
        end
      end
    end

    def conclusion?(name)
      self.conclusion == name
    end

    def init_stage
      stage = self.beginning
      allowed_transitions, allowed_actions = allowed_transitions_and_actions(stage)
      Types::WorkflowState.new(stage:, state: :in_progress, allowed_transitions:, allowed_actions:)
    end

    def with_transitions(new_transitions)
      transitions = [].concat(self.transitions, new_transitions)
      new_instance(transitions:)
    end

    def with_transition(from:, to:)
      [from, to].each do |stage|
        unless stage_names.include?(stage)
          raise TransitionError, "Stage #{stage} does not exist"
        end
      end

      if circular_transition?(from, to)
        raise TransitionError, "Circular transition detected"
      end

      attributes = { from:, to: }
      transition = Types::Transition.parse(attributes)
      transitions = [].concat(self.transitions, [transition])
      new_instance(transitions:)
    end

    def conclude_at(stage)
      new_instance(conclusion: stage)
    end

    def begin_with(stage)
      new_instance(beginning: stage)
    end

    def allowed_transitions_and_actions(stage)
      allowed_transitions = transitions.select { |transition| transition.from == stage }
      allowed_actions = allowed_transitions.map {|t| stages.find {|s| s.name == t.to }.action }.compact
      [allowed_transitions, allowed_actions]
    end

    private


    def stage_names
      @stage_names ||= stages.map(&:name)
    end



    def new_instance(new_attribs)
      attributes = self.attributes.merge(new_attribs)
      self.class.new(attributes)
    end

    def circular_transition?(from, to)
      return true if from == to

      transitions.select { |t| t.from == to }.each do |transition|
        return true if circular_transition?(from, transition.to)
      end

      false
    end

  end
end
