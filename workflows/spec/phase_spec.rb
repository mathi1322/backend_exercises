# frozen_string_literal: true

describe "Workflow Test" do

  context :transitions do
    before(:each) do
      @engine = Workflows::Engine.new
    end

    %w[a b c d].each do |alph|
      let("#{alph}_phase".to_sym) do
        stages = [1, 2, 3].map { |n| "#{alph}#{n}".to_sym }
        Workflows::Phase.new(prefix: alph.upcase.to_sym)
                        .with_stage_names(stages)
                        .with_transition(from: stages[0], to: stages[1])
                        .with_transition(from: stages[1], to: stages[2])
                        .begin_with(stages[0])
                        .conclude_at(stages[2])
      end

    end

    context :linear do
      it "should include a phase at the beginning when no other stage is present" do
        updated_engine = @engine.join_phase(a_phase)
        expect(updated_engine.beginning).to eq(:a1)
        expect(updated_engine.conclusion).to eq(:a3)

        expect(updated_engine.stages).to include(
                                           Workflows::Types::Stage.new(name: :a1, phase: :A),
                                           Workflows::Types::Stage.new(name: :a2, phase: :A),
                                           Workflows::Types::Stage.new(name: :a3, phase: :A)
                                         )
        expect(updated_engine.transitions).to include(
                                                Workflows::Types::Transition.new(from: :a1, to: :a2),
                                                Workflows::Types::Transition.new(from: :a2, to: :a3)
                                              )
      end

      it "should add to existing stages and transitions" do
        engine = @engine.join_phase(a_phase)
        updated_engine = engine.join_phase(b_phase)

        expect(updated_engine.beginning).to eq(:a1)
        expect(updated_engine.conclusion).to eq(:b3)
        expect(updated_engine.stages).to include(
                                           Workflows::Types::Stage.new(name: :b1, phase: :B),
                                           Workflows::Types::Stage.new(name: :b2, phase: :B),
                                           Workflows::Types::Stage.new(name: :b3, phase: :B)
                                         )
        expect(updated_engine.transitions).to include(
                                                Workflows::Types::Transition.new(from: :a3, to: :b1),
                                                Workflows::Types::Transition.new(from: :b1, to: :b2),
                                                Workflows::Types::Transition.new(from: :b2, to: :b3)
                                              )
      end

      it "should add to the unconcluded stage when there is no conclusion" do
        x_phase = Workflows::Phase.new(prefix: :X)
                                  .with_stage_names(%i[x1 x2 x3])
                                  .with_transition(from: :x1, to: :x2)
                                  .with_transition(from: :x2, to: :x3)
                                  .begin_with(:x1)
        engine = @engine.join_phase(x_phase)
        updated_engine = engine.join_phase(b_phase)

        expect(updated_engine.beginning).to eq(:x1)
        expect(updated_engine.conclusion).to eq(:b3)
        expect(updated_engine.stages).to include(
                                           Workflows::Types::Stage.new(name: :b1, phase: :B),
                                           Workflows::Types::Stage.new(name: :b2, phase: :B),
                                           Workflows::Types::Stage.new(name: :b3, phase: :B)
                                         )
        expect(updated_engine.transitions).to include(
                                                Workflows::Types::Transition.new(from: :x3, to: :b1),
                                                Workflows::Types::Transition.new(from: :b1, to: :b2),
                                                Workflows::Types::Transition.new(from: :b2, to: :b3)
                                              )

      end

      it "should add to all unconcluded stages when there is no conclusion" do
        x_phase = Workflows::Phase.new(prefix: :X)
                                  .with_stage_names(%i[x1 ucx2 x3 ucx4])
                                  .with_transition(from: :x1, to: :ucx2)
                                  .with_transition(from: :x1, to: :x3)
                                  .with_transition(from: :x3, to: :ucx4)
                                  .begin_with(:x1)
        engine = @engine.join_phase(x_phase)
        updated_engine = engine.join_phase(b_phase)

        expect(updated_engine.beginning).to eq(:x1)
        expect(updated_engine.conclusion).to eq(:b3)
        expect(updated_engine.stages).to include(
                                           Workflows::Types::Stage.new(name: :b1, phase: :B),
                                           Workflows::Types::Stage.new(name: :b2, phase: :B),
                                           Workflows::Types::Stage.new(name: :b3, phase: :B)
                                         )
        expect(updated_engine.transitions).to include(
                                                Workflows::Types::Transition.new(from: :ucx4, to: :b1),
                                                Workflows::Types::Transition.new(from: :ucx2, to: :b1),
                                                Workflows::Types::Transition.new(from: :b1, to: :b2),
                                                Workflows::Types::Transition.new(from: :b2, to: :b3)
                                              )

      end
    end

    xcontext :multi do
      it "should be able to add more than one phase to an engine" do
        engine = @engine.join_phase(a_phase)
        updated_engine = engine.join_phase(b_phase, c_phase)

        expect(updated_engine.beginning).to eq(:a1)
        expect(updated_engine.conclusion).not_to eq(:b3)
        expect(updated_engine.stages).to include(
                                           Workflows::Types::Stage.new(name: :b1, phase: :B),
                                           Workflows::Types::Stage.new(name: :b2, phase: :B),
                                           Workflows::Types::Stage.new(name: :b3, phase: :B),
                                           Workflows::Types::Stage.new(name: :c1, phase: :C),
                                           Workflows::Types::Stage.new(name: :c2, phase: :C),
                                           Workflows::Types::Stage.new(name: :c3, phase: :C)
                                         )
        expect(updated_engine.transitions).to include(
                                                Workflows::Types::Transition.new(from: :a3, to: :b1),
                                                Workflows::Types::Transition.new(from: :b1, to: :b2),
                                                Workflows::Types::Transition.new(from: :b2, to: :b3),
                                                Workflows::Types::Transition.new(from: :a3, to: :c1),
                                                Workflows::Types::Transition.new(from: :c1, to: :c2),
                                                Workflows::Types::Transition.new(from: :c2, to: :c3),
                                              )
      end
    end

  end
end
