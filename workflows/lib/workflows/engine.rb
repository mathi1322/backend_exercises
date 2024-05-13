module Workflows
  include Dry.Types

  class Engine < Dry::Struct
    include Workflows::Meta

    

    def start_phase(phase)
      raise TransitionError unless self.stages.empty?
      self.class.new(phase.attributes)
    end

    def join_phase(phase, join_action:)
      raise TransitionError if self.stages.empty?

      join_from = self.conclusion
      join_to = phase.beginning
      self.with_stages(phase.stages)
          .with_transition(from: join_from, to: join_to, action: join_action)
          .with_transitions(phase.transitions)
          .conclude_at(phase.conclusion)
    end

    def move_to(entity, stage)
      unless stage_names.include?(stage)
        raise TransitionError, "Invalid Stage #{stage}"
      end

      intent = Types::Transition.new(from: entity.stage, to: stage)
      if transitions.none? { |t| t == intent }
        raise TransitionError, "Invalid Transition from #{entity.stage} to #{stage}"
      end

      state = stage == conclusion ? :success : :in_progress
      allowed_transitions = compute_allowed_transitions(stage)
      entity.workflow_state.change(stage:, state:, allowed_transitions:)
    end

    def execute(entity, action)
      return if entity.action == action

      to_stage = stages.find { |s| s.action == action }
      raise TransitionError, "Action #{action} does not exist" if to_stage.nil?

      current_stage = entity.stage

      transition = transitions.find {|t| t.from == current_stage && t.to == to_stage.name }

      # normal transition action flow
      raise TransitionError, "Action #{action} cannot be called now" if transition.nil?

      approval_state = to_stage.approval ? :in_review : :none
      stage = to_stage.name
      entity.workflow_state.change(stage:, action:, approval_state:)

    end

    def approve(entity)
      run_approval(entity, :approved)
    end

    def reject(entity)
      run_approval(entity, :rejected)
    end

    private
    def run_approval(entity, action)
      stage_name = entity.stage
      stage = stages.find { |s| s.name == stage_name }
      raise TransitionError, "Current stage #{stage_name} does not have approvals" unless stage.approval
      entity.workflow_state.change(approval_state: action)
    end

  end
end
