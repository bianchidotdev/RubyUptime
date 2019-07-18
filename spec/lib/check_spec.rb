RSpec.describe RubyUptime::Check do

  describe '#new' do
    context 'check without specified default' do
      subject { Check.new('testland') }
      it 'creates with a merge of user-default and system default options' do
        expect(subject).to_not be_nil
        expect(subject.error).to be_nil
        expect(subject.valid?).to be(true)
        expect(subject.uri.to_s).to eq('https://config.lab.testland.auth0.com/testall')
        expect(subject.frequency).to eq(30)
      end
    end
  end

  context 'check with specified default parent' do
    subject { Check.new('testland-prod') }
    it 'creates with a merge of prod default and system default options' do
      expect(subject).to_not be_nil
      expect(subject.error).to be_nil
      expect(subject.valid?).to be(true)
      expect(subject.uri.to_s).to eq('https://config.lab.testland.auth0.com/testall')
      expect(subject.frequency).to eq(10)
      expect(subject.headers).to eq({'User-Agent' => 'RubyUptime/1.0.0'})
    end
  end

  context 'check with headers' do
    subject { Check.new('testland-dev') }
    it 'is created with both application default and user defined config' do
      expect(subject).to_not be_nil
      expect(subject.error).to be_nil
      expect(subject.valid?).to be(true)
      expect(subject.uri.to_s).to eq('https://config.lab.testland.auth0.com/testall')
      expect(subject.frequency).to eq(60)

      headers = {
        'Host' => 'a0-1.config.lab.testland.auth0.com',
        'User-Agent' => 'RubyUptime/1.0.0'
      }
      expect(subject.headers).to eq(headers)
    end
  end

  describe '#ready?' do
    subject { Check.new('testland-dev') }
    it 'correctly returns true if current time is sooner than last time' do
      expect(subject.ready?).to be(true)
    end

    context 'stubbed time' do
      before do
        allow(Time).to receive(:now).and_return(Time.now - 10)
      end
      it 'returns false if time is prior to next_time' do
        expect(subject.ready?).to be(false)
      end
    end
  end

  describe '#start_request' do
    subject { Check.new('testland-dev') }
    # let(:eval_id) { SecureRandom.hex(9) }

    it 'makes the request and set the @requests var successfully' do
      eval_id = SecureRandom.hex(9)
      stub = stub_request(:get, subject.uri).
         to_return(status: 200, body: 'OK', headers: {})

      subject.start_request(eval_id)
      expect(stub).to have_been_requested
      expect(subject.requests[eval_id][:resp].status).to eq(200)
      expect(subject.requests[eval_id][:resp].body.to_s).to match(/OK/)
    end

    # it 'handles timeout gracefully' do
    #   eval_id = SecureRandom.hex(9)
    #   stub = stub_request(:get, subject.uri).
    #     to_raise()

    #   subject.start_request(eval_id)
    #   expect(stub).to have_been_requested
    #   expect(subject.requests[eval_id][:resp]).to be(true)
    # end
  end

  describe '#successful?' do
    # TODO: need to add tests for all possible success criteria here
  end

  describe '#on_success' do
    # TODO: Make sure it resets failure counter
  end

  describe '#on_failure' do
    # TODO: Make sure it respects and decrements failure counter
  end
end