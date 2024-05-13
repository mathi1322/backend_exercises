module Workflows
  include Dry.Types

  class Engine < Dry::Struct
    attribute :stages, Types::Array.of(Workflows::Types::Stage).default { [] }
    attribute :transitions, Types::Array.of(Workflows::Types::Transition).default { [] }
    attribute? :conclusion, Types::Strict::Symbol

    def init_stage
      stage = stages.first.name
      allowed_transitions = compute_allowed_transitions(stage)
      Types::WorkflowState.new(stage:, state: :in_progress, allowed_transitions:)
    end


    def with_stage_names(new_names)
      new_stages = new_names.map {|n| Workflows::Types::Stage.new(name: n)}
      with_stages(new_stages)
    end

    def with_stages(new_stages)
      stages = [].concat(self.stages, new_stages)
      new_instance(stages:)
    end

    def with_transition(from:, to:, action: nil, approve_action: nil)
      [from, to].each do |stage|
        unless stage_names.include?(stage)
          raise TransitionError, "Stage #{stage} does not exist" 
        end
      end

      if circular_transition?(from, to)
        raise TransitionError, "Circular transition detected"
      end

      attributes = {from:, to:}
      attributes[:action] = action if action
      attributes[:approve_action] = approve_action if approve_action
      transition = Types::Transition.parse(attributes)
      transitions = [].concat(self.transitions, [transition])
      new_instance(transitions:)
    end

    def conclude_at(stage)
      new_instance(conclusion: stage)
    end


    def move_to(entity, stage)
      unless stage_names.include?(stage)
        raise TransitionError, "Invalid Stage #{stage}" 
      end

      intent = Types::Transition.new(from: entity.stage, to: stage)
      if transitions.none? {|t| t == intent }
        raise TransitionError, "Invalid Transition from #{entity.stage} to #{stage}"
      end

      state = stage == conclusion ? :success : :in_progress
      allowed_transitions = compute_allowed_transitions(stage)
      entity.workflow_state.change(stage:, state:, allowed_transitions:)
    end

    def execute(entity, action, *params)
      return if entity.action == action

      transition = transitions.find { |t| t.action == action }

      if transition.nil?
        if approve_action?(action) # approval action flow
          run_approval(entity, action, *params) 
        else
          raise TransitionError, "Action #{action} does not exist" if transition.nil?
        end
      else # normal transition action flow
        raise TransitionError, "Action #{action} cannot be called now" if transition.from != entity.stage

        approval_state = transition.approve_action ? :in_review : :none
        stage =  transition.approve_action ? entity.stage : transition.to
        entity.workflow_state.change(stage:, action:, approval_state:)
      end
    end

    def run_approval(entity, action, *params)
      is_approved = params.first
      transition = transitions.find { |t| t.approve_action == action }
      approval_state = is_approved ? :approved : :rejected
      stage = approval_state == :rejected ? entity.stage : transition.to
      entity.workflow_state.change(stage:, approval_state:)
    end

    private

    def approve_action?(action)
      transitions.any? { |t| t.approve_action == action }
    end

    def stage_names
      @stage_names ||= stages.map(&:name)
    end

    def compute_allowed_transitions(stage)
      transitions.select { |transition| transition.from == stage }
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
