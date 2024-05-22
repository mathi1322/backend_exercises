# frozen_string_literal: true

describe "Workflow Test" do

  context :transitions do
    %w[a b c d].each do |alph|
      let("#{alph}_phase".to_sym) do
        stages = [1, 2, 3].map do |n|
          name = "#{alph}#{n}".to_sym
          action = "do_#{name}".to_sym
          Workflows::Types::Stage.new(name:, action:)
        end
        names = stages.map(&:name)
        Workflows::Types::Phase.new(name: alph.upcase.to_sym)
                               .with_stages(stages)
                               .with_transition(from: names[0], to: names[1])
                               .with_transition(from: names[1], to: names[2])
                               .begin_with(names[0])
                               .conclude_at(names[2])
      end

    end

    context :linear do
      before(:each) do
        @engine = Workflows::Engine.new
                                   .with_phase(a_phase)
                                   .with_phase(b_phase)
                                   .begin_with(:A)
                                   .conclude_at(:B)
                                   .with_transition(from: :A, to: :B)
      end
      let(:engine) { @engine }
      let(:entity) { Workflows::Entity.new.tap { |e| e.init(strategy: engine) } }

      it "should transition from all unconcluded stages when there is no conclusion" do
        x_phase = Workflows::Types::Phase.new(name: :X)
                                         .with_stage_names(%i[x1 ucx2 x3 ucx4])
                                         .with_transition(from: :x1, to: :ucx2)
                                         .with_transition(from: :x1, to: :x3)
                                         .with_transition(from: :x3, to: :ucx4)
                                         .begin_with(:x1)

        engine = Workflows::Engine.new
                                  .with_phase(x_phase)
                                  .with_phase(b_phase)
                                  .begin_with(:X)
                                  .with_transition(from: :X, to: :B)
                                  .conclude_at(:B)

        entity = Workflows::Entity.new.tap { |e| e.init(strategy: engine) }
        entity.transition_to!(:ucx2)
              .transition_to!(:b1)
              .execute(:do_b2)
              .execute(:do_b3)

        expect(entity.state).to eq(:success)

        entity = Workflows::Entity.new.tap { |e| e.init(strategy: engine) }
        entity.transition_to!(:x3)
              .transition_to!(:ucx4)
              .execute(:do_b1)
              .execute(:do_b2)
              .execute(:do_b3)

        expect(entity.state).to eq(:success)

      end
    end

    context :multi do
      before(:each) do
        @engine = Workflows::Engine.new
                                   .with_phase(a_phase)
                                   .with_phase(b_phase)
                                   .with_phase(c_phase)
                                   .with_phase(d_phase)
                                   .begin_with(:A)
                                   .conclude_at(:D)
                                   .with_transition(from: :A, to: :B)
                                   .with_transition(from: :A, to: :C)
                                   .with_transition(from: :B, to: :D)
                                   .with_transition(from: :C, to: :D)
      end

      let(:engine) { @engine }
      let(:entity) { Workflows::Entity.new.tap { |e| e.init(strategy: engine) } }

      it "should transition to D through B" do
        entity.execute(:do_a2)
              .execute(:do_a3)
              .execute(:do_b1)
              .execute(:do_b2)
              .execute(:do_b3)
              .execute(:do_d1)
              .execute(:do_d2)
              .execute(:do_d3)
        expect(entity.state).to eq(:success)
      end

      it "should transition to D through C" do
        entity.execute(:do_a2)
              .execute(:do_a3)
              .execute(:do_c1)
              .execute(:do_c2)
              .execute(:do_c3)
              .execute(:do_d1)
              .execute(:do_d2)
              .execute(:do_d3)
        expect(entity.state).to eq(:success)
      end
    end

  end
end
