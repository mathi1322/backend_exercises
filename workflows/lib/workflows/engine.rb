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

    def with_transition(from:, to:)
      [from, to].each do |name|
        unless !!find_phase(name)
          raise TransitionError, "Phase #{name} does not exist"
        end
      end

      if circular_transition?(from, to)
        raise TransitionError, "Circular transition detected"
      end

      attributes = { from:, to: }
      transition = Types::Transition.parse(attributes)
      transitions = self.transitions | [transition]
      new_instance(transitions:)
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

    def move_to(present_state, stage)

      unless stage_present?(stage)
        raise TransitionError, "Invalid Stage #{stage}"
      end

      current_stage_name = present_state.stage
      current_phase_name = present_state.phase
      current_phase = find_phase(current_phase_name)
      if current_phase.final_stage?(current_stage_name)
        stages = joining_stages(current_phase_name)
        raise TransitionError, "Stage #{stage} does not exist or invalid from #{current_stage_name}." if stages.empty?
        to_stage = stages.find { |s| s.name == stage }
        raise TransitionError, "Action #{action} does not exist or invalid from #{current_stage_name}." if to_stage.nil?
        update_workflow_state(present_state, to_stage)
      else
        unless current_phase.include_transition?(from: current_stage_name, to: stage)
          raise TransitionError, "Invalid Transition from #{current_stage_name} to #{stage}"
        end
        to = current_phase.find_stage(name: stage)
        update_workflow_state(present_state, to)
      end

    end

    def execute(present_state, action)
      raise TransitionError, "Action #{action} cannot be performed while waiting for approval" if present_state.in_review?
      current_stage_name = present_state.stage
      current_phase_name = present_state.phase
      current_phase = find_phase(current_phase_name)
      if current_phase.final_stage?(current_stage_name)
        stages = joining_stages(current_phase_name)
        raise TransitionError, "Action #{action} does not exist or invalid from #{current_stage_name}." if stages.empty?
        to_stage = stages.find { |s| s.action == action }
        raise TransitionError, "Action #{action} does not exist or invalid from #{current_stage_name}." if to_stage.nil?
        update_workflow_state(present_state, to_stage)
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

        update_workflow_state(present_state, to_stage)
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

    # TODO: refactor.. this is copied code from configuration.rb
    def circular_transition?(from, to)
      return true if from == to

      transitions.select { |t| t.from == to }.each do |transition|
        return true if circular_transition?(from, transition.to)
      end

      false
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

    def update_workflow_state(present_state, to_stage)
      approval_state = to_stage.approval ? :in_review : :none
      stage = to_stage.name
      phase_name = to_stage.phase
      action = to_stage.action
      phase = find_phase(phase_name)
      allowed_transitions, allowed_actions = [[], []]
      unless to_stage.approval && approval_state == :in_review
        if phase.final_stage?(stage)
          allowed_transitions = join_transitions(stage)
          allowed_actions = join_actions(stage)
        else
          allowed_transitions, allowed_actions = to_stage.approval ? [[], []] : phase.allowed_transitions_and_actions(stage)
        end
      end
      state = conclusion?(stage) ? :success : :in_progress
      present_state.change(phase: phase_name, state:, stage:, action:, approval_state:, allowed_transitions:, allowed_actions:)
    end

    def join_transitions(from)
      phase = phases.find { |p| p.include_stage?(from) }
      joining_stages(phase.name)
        .map { |to| Workflows::Types::Transition.new(from:, to: to.name) }
    end

    def join_actions(from)
      phase = phases.find { |p| p.include_stage?(from) }
      joining_stages(phase.name)
        .map(&:action)
    end

    def joining_stages(phase_name)
      next_phases(phase_name)
        .map(&:begin_stage)
    end

    def next_phases(name)
      transitions.select { |t| t.from == name }
                 .map { |t| find_phase(t.to) }

    end
  end
end
