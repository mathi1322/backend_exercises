module Workflows
  include Dry.Types

  class Engine < Dry::Struct
    include Workflows::Configuration

    def join_phase(phase)
      return self.class.new(phase.attributes) if self.stages.empty?

      last_stage = self.conclusion

      join_froms = if last_stage.nil?
                    self.unconcluded_stages.map(&:name)
                  else
                    [last_stage]
                  end
      join_to = phase.beginning

      join_transitions = join_froms.map do |join_from|
        Workflows::Types::Transition.new(from: join_from, to: join_to)
      end

      transitions = [].concat(join_transitions, phase.transitions)

      with_stages = self.with_stages(phase.stages)
      with_transitions = with_stages.with_transitions(transitions) unless transitions.empty?
      conclusion = phase.conclusion
      conclusion.nil? ? with_transitions : with_transitions.conclude_at(conclusion)
    end

    def move_to(present_state, stage)
      unless stage_names.include?(stage)
        raise TransitionError, "Invalid Stage #{stage}"
      end

      intent = Types::Transition.new(from: present_state.stage, to: stage)
      if transitions.none? { |t| t == intent }
        raise TransitionError, "Invalid Transition from #{present_state.stage} to #{stage}"
      end

      state = stage == conclusion ? :success : :in_progress
      allowed_transitions, allowed_actions = allowed_transitions_and_actions(stage)
      present_state.change(stage:, state:, allowed_transitions:, allowed_actions:)
    end

    def execute(present_state, action)
      current_stage_name = present_state.stage
      raise TransitionError, "Action #{action} cannot be performed while waiting for approval" if present_state.in_review?
      current_stage = stages.find { |s| s.name == current_stage_name }
      to_stage = stages.find { |s| s.action == action }
      raise TransitionError, "Action #{action} does not exist" if to_stage.nil?

      unless present_state.approval_state == :rejected
        return if current_stage.action == action

        transition = transitions.find {|t| t.from == current_stage_name && t.to == to_stage.name }
        # normal transition action flow
        raise TransitionError, "Action #{action} cannot be called now" if transition.nil?
      end

      update_workflow_state(present_state, to_stage, action)
    end

    def approve(entity)
      run_approval(entity, :approved)
    end

    def reject(entity)
      run_approval(entity, :rejected)
    end

    private

    def unconcluded_stages
      concluded_stage_names = transitions.map(&:from).uniq
      self.stages.reject { |s| concluded_stage_names.include?(s.name) }
    end
    def run_approval(present_state, action)
      stage_name = present_state.stage
      stage = stages.find { |s| s.name == stage_name }
      raise TransitionError, "Current stage #{stage_name} does not have approvals" unless stage.approval
      present_state.change(approval_state: action)
    end

    def update_workflow_state(present_state, to_stage, action)
      approval_state = to_stage.approval ? :in_review : :none
      stage = to_stage.name
      phase = to_stage.phase
      # state = to_stage.name == conclusion ? :success : :in_progress
      allowed_transitions, allowed_actions = to_stage.approval ? [[],[]] : allowed_transitions_and_actions(stage)
      present_state.change(phase:, stage:, action:, approval_state:, allowed_transitions:, allowed_actions:)
    end
  end
end
