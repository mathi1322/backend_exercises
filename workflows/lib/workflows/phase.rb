# frozen_string_literal: true

module Workflows
  class Phase < Dry::Struct
    include Workflows::Meta

    attribute :prefix, Types::Strict::Symbol

  end
end
