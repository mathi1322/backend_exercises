module Workflows
  include Dry.Types

  class Entity
    def init(strategy:)
      @strategy = strategy
      @workflow_state = strategy.init_stage
    end

    %i[state stage action allowed_transitions approval_state].each do |attribute|
      delegate attribute, to: :workflow_state
    end

    attr_reader :strategy

    def transition_to!(to_state)
      @workflow_state = strategy.move_to(self, to_state)
      self
    end

    def execute(action, *)
      @workflow_state = strategy.execute(self, action, *)
      self
    end

    attr_reader :workflow_state
  end
end
