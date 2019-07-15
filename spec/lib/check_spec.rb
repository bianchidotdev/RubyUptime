RSpec.describe RubyUptime::Check do

  describe '#new' do
    context 'check without specified default' do
      subject { Check.new('testland') }
      it 'creates with a merge of user-default and system default options' do
        expect(subject).to_not be_nil
        expect(subject.error).to be_nil
        expect(subject.valid?).to be(true)
        expect(subject.uri.to_s).to eq('https://config.lab.testland.auth0.com/testall')
      end
    end
  end
end