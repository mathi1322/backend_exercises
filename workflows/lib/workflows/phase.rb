# frozen_string_literal: true

module Workflows
  module Types
    class Phase < Dry::Struct
      include Workflows::Configuration

      attribute :name, Types::Strict::Symbol
      attribute :stages, Types::Array.of(Workflows::Types::Stage).default { [] }

      def with_stages(new_stages)
        updated_stages = new_stages.map { |s| s.with_phase(name) }
        stages = [].concat(self.stages, updated_stages)
        new_instance(stages:)
      end

      def with_stage_names(new_names)
        new_stages = new_names.map { |n| Workflows::Types::Stage.new(name: n) }
        with_stages(new_stages)
      end

      def self.parse(data)
        stages = data[:stages].map { |sd| Workflows::Types::Stage.parse(sd) }
        super(data.merge(stages:))
      end

      def include_stage?(name)
        !!find_stage(name:)
      end

      def final_stage?(name)
        final_stages.any? { |s| s.name == name }
      end

      def include_transition?(from:, to:)
        transition = Types::Transition.new(from:, to:)
        transitions.any? { |t| t == transition }
      end

      def final_stages
        conclusion.nil? ? unconcluded_stages : [find_stage(name: self.conclusion)]
      end

      def find_stage(**attribs)
        stages.find { |s| attribs.keys.all? {|k| s.public_send(k) == attribs[k] } }
      end


      private
      def unconcluded_stages
        concluded_stage_names = transitions.map(&:from).uniq
        self.stages.reject { |s| concluded_stage_names.include?(s.name) }
      end

    end
  end
end
