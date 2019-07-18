
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
			expect(subject.checks.count).to be(6)
			expect(subject.checks.map(&:valid?)).to eq(Array.new(6, true))
		end
	end

	describe '#eval_check' do
		context 'single check' do
			subject { CheckManager.new }
			let(:check) { subject.checks.first }
			
			it 'does something?' do
				expect(subject.eval_check(check)).to be(true)
			end
		end
	end
end