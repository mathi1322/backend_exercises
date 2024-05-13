describe "Workflow Test" do

  context :transitions do
    before(:each) do
      @engine = Workflows::Engine.new
                                 .with_stage_names(%i[a b c d e f g])
                                 .with_transition(from: :a, to: :b)
                                 .with_transition(from: :a, to: :c)
                                 .with_transition(from: :c, to: :d)
                                 .with_transition(from: :b, to: :e)
                                 .with_transition(from: :d, to: :f)
                                 .with_transition(from: :e, to: :f)
                                 .with_transition(from: :f, to: :g)
                                 .begin_with(:a)
                                 .conclude_at(:g)
    end

    let(:engine) { @engine }

    let(:entity) { Workflows::Entity.new.tap { |e| e.init(strategy: engine) } }

    it "should initialize entity to the first stage" do
      expect(entity.stage).to eq(:a)
    end

    it "should transition to b" do
      entity.transition_to!(:b)
      expect(entity.stage).to eq(:b)
      expect(entity.state).to eq(:in_progress)
    end

    it "should also transition from a to b" do
      entity.transition_to!(:c)
      expect(entity.stage).to eq(:c)
      expect(entity.state).to eq(:in_progress)
    end

    it "should not directly transition from a to e" do
      expect {
        entity.transition_to!(:e)
      }.to raise_error(Workflows::TransitionError, "Invalid Transition from a to e")
    end

    it "should not transition to k" do
      expect {
        entity.transition_to!(:k)
      }.to raise_error(Workflows::TransitionError, "Invalid Stage k")
    end

    it "should conclude at g" do
      entity.transition_to!(:c)
            .transition_to!(:d)
            .transition_to!(:f)
            .transition_to!(:g)
      expect(entity.stage).to eq(:g)
      expect(entity.state).to eq(:success)
    end

    it "should provide possible transitions at any state" do
      expected = [
        Workflows::Types::Transition.new(from: :a, to: :b),
        Workflows::Types::Transition.new(from: :a, to: :c)
      ]
      expect(entity.allowed_transitions).to eq(expected)
    end  
  end

  context :actions do
    before(:each) do
      stages = [
        Workflows::Types::Stage.new(name: :created),
        Workflows::Types::Stage.new(name: :designed, action: :upload_design),
        Workflows::Types::Stage.new(name: :supplier_quotes_updated, action: :update_supplier_quote, approval: true),
        Workflows::Types::Stage.new(name: :buyer_quote_confirmed, action: :confirm_buyer_quote, approval: true),
        Workflows::Types::Stage.new(name: :sale_contract_prepared, action: :prepare_sale_contract, approval: true),
      ]

      @engine = Workflows::Engine.new
                                 .with_stages(stages)
                                 .with_transition(from: :created, to: :designed)
                                 .with_transition(from: :designed, to: :supplier_quotes_updated)
                                 .with_transition(from: :supplier_quotes_updated, to: :buyer_quote_confirmed)
                                 .with_transition(from: :buyer_quote_confirmed, to: :sale_contract_prepared)
                                 .begin_with(:created)
                                 .conclude_at(:sale_contract_prepared)
    end

    let(:engine) { @engine }
    let(:entity) { Workflows::Entity.new.tap { |e| e.init(strategy: engine) } }

    it "should use action :upload_design to transition to :designed" do
      entity.execute(:upload_design)
      expect(entity.stage).to eq(:designed)
    end

    it 'should provide all allowed actions' do
      expect(entity.allowed_actions).to eq([:upload_design])
      entity.execute(:upload_design)
      expect(entity.allowed_actions).to eq([:update_supplier_quote])
    end

    it "should not have nil in allowed actions" do
      stages = [
        Workflows::Types::Stage.new(name: :created),
        Workflows::Types::Stage.new(name: :designed, action: :upload_design),
        Workflows::Types::Stage.new(name: :copied),
      ]
      @engine = Workflows::Engine.new
                                 .with_stages(stages)
                                 .with_transition(from: :created, to: :designed)
                                 .with_transition(from: :created, to: :copied)
                                 .begin_with(:created)

      expect(entity.allowed_actions).to eq([:upload_design])
    end

    it "should raise error if action does not exist" do
      expect{entity.execute(:x)}.to raise_error(Workflows::TransitionError, "Action x does not exist")
    end

    it "should not raise error when called multiple time in sequence" do
      entity.execute(:upload_design)
      expect(entity.stage).to eq(:designed)
      expect { entity.execute(:upload_design) }.not_to raise_error
    end

    it "should raise error when an action called the second time but not in sequence" do
      entity.execute(:upload_design)
      entity.execute(:update_supplier_quote)
      expect { entity.execute(:upload_design) }.to raise_error(Workflows::TransitionError)
    end

    it "should raise error when an action called out of turn" do
      entity.execute(:upload_design)
      expect { entity.execute(:confirm_buyer_quote) }.to raise_error(Workflows::TransitionError)
    end

    context :approvals do
      it "should allow approval" do
        entity.execute(:upload_design)
        expect(entity.approval_state).to eq(:none)
        expect(entity.stage).to eq(:designed)

        entity.execute(:update_supplier_quote)
        expect(entity.approval_state).to eq(:in_review)
        expect(entity.stage).to eq(:supplier_quotes_updated)

        entity.execute(:approve)
        expect(entity.stage).to eq(:supplier_quotes_updated)
        expect(entity.approval_state).to eq(:approved)
      end

      it "should allow rejection" do
        entity.execute(:upload_design)
        expect(entity.approval_state).to eq(:none)
        expect(entity.stage).to eq(:designed)

        entity.execute(:update_supplier_quote)
        expect(entity.approval_state).to eq(:in_review)
        expect(entity.stage).to eq(:supplier_quotes_updated)

        entity.execute(:reject)
        expect(entity.stage).to eq(:supplier_quotes_updated)
        expect(entity.approval_state).to eq(:rejected)
      end

      it "should not allow approvals when there is none" do
        entity.execute(:upload_design)
        expect(entity.approval_state).to eq(:none)

        expect {
          entity.execute(:approve)
        }.to raise_error(Workflows::TransitionError)

        expect {
          entity.execute(:reject)
        }.to raise_error(Workflows::TransitionError)
      end

      it "should update to in_review when action executed again after rejection" do
        entity.execute(:upload_design)
        entity.execute(:update_supplier_quote)

        entity.execute(:reject)
        expect(entity.stage).to eq(:supplier_quotes_updated)
        expect(entity.approval_state).to eq(:rejected)

        entity.execute(:update_supplier_quote)
        expect(entity.stage).to eq(:supplier_quotes_updated)
        expect(entity.approval_state).to eq(:in_review)
      end

      it "should not allow any custom action to have name :approve or :reject" do
        expect {
          Workflows::Types::Stage.new(name: :designed, action: :approve)
        }.to raise_error(Workflows::DefinitionError)

        expect {
          Workflows::Types::Stage.new(name: :designed, action: :reject)
        }.to raise_error(Workflows::DefinitionError)
      end
    end
  end

  context :validations do
    it "should not allow non-existent to stage in transitions" do
      engine = Workflows::Engine.new
                                .with_stage_names(%i[a b])
                                .with_transition(from: :a, to: :b)
                                .begin_with(:a)
                                .conclude_at(:b)
      expect {
        engine.with_transition(from: :a, to: :c)
      }.to raise_error("Stage c does not exist")
      expect {
        engine.with_transition(from: :x, to: :b)
      }.to raise_error("Stage x does not exist")
    end

    it "should not allow circular references in transitions" do
      engine = Workflows::Engine.new
                                .with_stage_names(%i[a b c d e])
                                .with_transition(from: :a, to: :b)
                                .with_transition(from: :a, to: :c)
                                .with_transition(from: :b, to: :e)
                                .with_transition(from: :c, to: :d)
                                .with_transition(from: :d, to: :b)
      expect {
        engine.with_transition(from: :e, to: :c)
      }.to raise_error("Circular transition detected")
    end
  end
end
