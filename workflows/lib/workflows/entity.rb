module Workflows
  include Dry.Types

  class Entity
    def init(strategy:)
      @strategy = strategy
      @workflow_state = strategy.init_stage
    end

    %i[state phase stage action allowed_transitions allowed_actions approval_state].each do |attribute|
      delegate attribute, to: :workflow_state
    end

    attr_reader :strategy

    def transition_to!(to_state)
      @workflow_state = strategy.move_to(@workflow_state, to_state)
      self
    end

    def execute(action, *)
      if %i[approve reject].include?(action)
        @workflow_state = strategy.public_send(action, @workflow_state)
      else
        @workflow_state = strategy.execute(@workflow_state, action, *)
      end
      self
    end

    attr_reader :workflow_state
  end
end
