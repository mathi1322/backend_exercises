# frozen_string_literal: true

module Workflows
  class Phase < Dry::Struct
    include Workflows::Configuration

    attribute :prefix, Types::Strict::Symbol

    def with_stages(new_stages)
      super(new_stages.map { |s| s.with_phase(prefix) })
    end

  end
end
