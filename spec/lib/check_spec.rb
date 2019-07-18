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
    it 'correctly returns true if current time is sooner than last time' do
      
    end
  end
end