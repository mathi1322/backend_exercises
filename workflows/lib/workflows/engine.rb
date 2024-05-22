module Workflows
  include Dry.Types

  class Engine < Dry::Struct
    # include Workflows::Configuration
    attribute :phases, Types::Array.of(Workflows::Types::Phase).default { [] }
    attribute :transitions, Types::Array.of(Workflows::Types::Transition).default { [] }
    attribute? :beginning, Types::Strict::Symbol
    attribute? :conclusion, Types::Strict::Symbol

    def with_phase(phase)
      new_phases = phases | [phase]
      new_instance(phases: new_phases)
    end

    def begin_with(phase)
      new_instance(beginning: phase)
    end

    def conclude_at(phase)
      new_instance(conclusion: phase)
    end

    def init_stage
      first_phase = find_phase(self.beginning)
      stage = first_phase.beginning
      allowed_transitions, allowed_actions = first_phase.allowed_transitions_and_actions(stage)
      Types::WorkflowState.new(phase: first_phase.name, stage:, state: :in_progress, allowed_transitions:, allowed_actions:)
    end

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
      unless stage_present?(stage)
        raise TransitionError, "Invalid Stage #{stage}"
      end

      current_stage = present_state.stage
      current_phase = phases.find { |p| p.include_stage?(present_state.stage) }
      if current_phase.final_stage?(current_stage)
        raise "Not implemented"
      else
        unless current_phase.include_transition?(from: current_stage, to: stage)
          raise TransitionError, "Invalid Transition from #{current_stage} to #{stage}"
        end
        state = conclusion?(stage) ? :success : :in_progress
        allowed_transitions, allowed_actions = current_phase.allowed_transitions_and_actions(stage)
        present_state.change(stage:, state:, allowed_transitions:, allowed_actions:)
      end

    end

    def execute(present_state, action)
      raise TransitionError, "Action #{action} cannot be performed while waiting for approval" if present_state.in_review?
      current_stage_name = present_state.stage
      current_phase_name = present_state.phase
      current_phase = find_phase(current_phase_name)

      if current_phase.final_stage?(current_stage_name)
        raise "Not implemented"
      else
        current_stage = current_phase.find_stage(name: current_stage_name)

        to_stage = current_phase.find_stage(action:)
        raise TransitionError, "Action #{action} does not exist" if to_stage.nil?

        unless present_state.approval_state == :rejected
          return if current_stage.action == action
          # normal transition action flow
          unless current_phase.include_transition?(from: current_stage_name, to: to_stage.name)
            raise TransitionError, "Action #{action} cannot be called now"
          end
        end

        update_workflow_state(present_state, to_stage, action)
      end
    end

    def approve(entity)
      run_approval(entity, :approved)
    end

    def reject(entity)
      run_approval(entity, :rejected)
    end

    private

    def conclusion?(stage_name)
      phase = phases.find { |p| p.include_stage?(stage_name) }
      phase.name == self.conclusion && phase.conclusion?(stage_name)
    end

    def stage_present?(name)
      phases.any? { |p| p.include_stage?(name) }
    end

    def find_phase(name)
      phases.find { |p| p.name == name }
    end

    # ################### possible common methods ##############
    def new_instance(new_attribs)
      attributes = self.attributes.merge(new_attribs)
      self.class.new(attributes)
    end

    # ################### ###################### ##############

    def run_approval(present_state, action)
      stage_name = present_state.stage
      phase_name = present_state.phase
      phase = find_phase(phase_name)
      stage = phase.find_stage(name: stage_name)
      raise TransitionError, "Current stage #{stage_name} does not have approvals" unless stage.approval
      present_state.change(approval_state: action)
    end

    def update_workflow_state(present_state, to_stage, action)
      approval_state = to_stage.approval ? :in_review : :none
      stage = to_stage.name
      phase_name = to_stage.phase
      phase = find_phase(phase_name)
      # state = to_stage.name == conclusion ? :success : :in_progress
      allowed_transitions, allowed_actions = to_stage.approval ? [[], []] : phase.allowed_transitions_and_actions(stage)
      present_state.change(phase: phase_name, stage:, action:, approval_state:, allowed_transitions:, allowed_actions:)
    end
  end
end
