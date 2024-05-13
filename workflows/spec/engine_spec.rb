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

      stages = %i[created designed supplier_quotes_updated buyer_quote_confirmed sale_contract_prepared].map {|n| Workflows::Types::Stage.new(name: n)}

      @engine = Workflows::Engine.new
                                 .with_stages(stages)
                                 .with_transition(from: :created, to: :designed, action: :upload_design)
                                 .with_transition(from: :designed, to: :supplier_quotes_updated, action: :update_supplier_quote, approve_action: :approve_supplier_quote)
                                 .with_transition(from: :supplier_quotes_updated, to: :buyer_quote_confirmed, action: :confirm_buyer_quote)
                                 .with_transition(from: :buyer_quote_confirmed, to: :sale_contract_prepared)
                                 .conclude_at(:sale_contract_prepared)
    end

    let(:engine) { @engine }
    let(:entity) { Workflows::Entity.new.tap { |e| e.init(strategy: engine) } }

    it "should use action :upload_design to transition to :designed" do
      entity.execute(:upload_design)
      expect(entity.stage).to eq(:designed)
    end

    it "should raise error if action does not exist" do
      expect{entity.execute(:x)}.to raise_error(Workflows::TransitionError, "Action x does not exist")
    end

    it "should not raise error when called multiple time in sequence" do
      entity.execute(:upload_design)
      expect(entity.stage).to eq(:designed)
      expect { entity.execute(:upload_design) }.not_to raise_error(Workflows::TransitionError)
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

    it "should allow approval" do
      entity.execute(:upload_design)
      expect(entity.approval_state).to eq(:none)
      expect(entity.stage).to eq(:designed)

      entity.execute(:update_supplier_quote)
      expect(entity.approval_state).to eq(:in_review)
      expect(entity.stage).to eq(:designed)

      entity.execute(:approve_supplier_quote, false)
      expect(entity.stage).to eq(:designed)
      expect(entity.approval_state).to eq(:rejected)

      entity.execute(:approve_supplier_quote, true)
      expect(entity.approval_state).to eq(:approved)
      expect(entity.stage).to eq(:supplier_quotes_updated)
    end
  end
 
  context :validations do
    it "should not allow non-existent to stage in transitions" do
      engine = Workflows::Engine.new
                                .with_stage_names(%i[a b])
                                .with_transition(from: :a, to: :b)
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
