
RSpec.describe RubyUptime::UserConfig do
  describe '#new' do
    it 'loads defaults, checks, and merges them all' do
    end
  end

  describe '#files' do
    subject { RubyUptime::UserConfig.new }
    let(:check_dir) { AppConfig.paths.check_config_dir }
    it 'loads yml files in check dir' do
      expect(subject.config_files).to include("#{check_dir}/main.yml")
    end

    it 'loads yml.erb files in check dir' do
      expect(subject.config_files).to include("#{check_dir}/main.yml.erb")
    end

    it 'loads json files in check dir' do
      expect(subject.config_files).to include("#{check_dir}/main.json")
    end

    it 'loads files in sub-directories' do
      expect(subject.config_files).to include("#{check_dir}/service_a/service_a_1.yml")
    end

    it 'ignores the defaults file' do
      expect(subject.config_files).to_not include("#{check_dir}/#{AppConfig.paths.check_defaults_file}")
    end
  end

  describe '.check_config' do
    it 'contains all the example check configs' do
    end

    it 'has all fields from the check file and the default file' do
    end

    it 'merges checks with the default prioritizing the check settings' do
    end

    it 'allowed for specified defaults' do
    end
  end

end
