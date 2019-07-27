
RSpec.describe RubyUptime::CheckManager do
	describe '#load_user_config' do
		subject { CheckManager.new }
		it 'loads user config' do
			expect(subject.load_user_config).to be_an_instance_of(RubyUptime::UserConfig)
		end
	end

	describe '#create_checks' do
		subject { CheckManager.new }
		it 'creates all valid checks' do
			expect(subject.checks.count).to be(9)
			expect(subject.checks.map(&:valid?)).to eq(Array.new(9, true))
		end
	end

	describe '#eval_check' do
		context 'single check' do
			subject { CheckManager.new }
			let(:check) { subject.checks.first }

			before do
				stub_request(:get, check.uri)
			end
			
			it 'does something?' do
				
				expect(subject.eval_check(check)).to be(true)
			end
		end
	end
end