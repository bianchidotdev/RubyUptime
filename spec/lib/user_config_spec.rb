
RSpec.describe RubyUptime::UserConfig do  
  describe '#new' do
    it 'loads defaults, checks, and merges them all' do
    end
  end

  describe '#files' do
    let(:check_dir) { AppConfig.paths.check_config_dir }
    let(:check_defaults_file) { AppConfig.paths.check_defaults_file }
    before(:all) do
      subject = RubyUptime::UserConfig.instance
      @config_files = subject.config_files
    end

    it 'loads yml files in check dir' do
      expect(@config_files).to include("#{check_dir}/main.yml")
    end

    it 'loads yml.erb files in check dir' do
      expect(@config_files).to include("#{check_dir}/main.yml.erb")
    end

    it 'loads json files in check dir' do
      expect(@config_files).to include("#{check_dir}/main.json")
    end

    it 'loads files in sub-directories' do
      expect(@config_files).to include("#{check_dir}/service_a/service_a_1.yml")
    end

    it 'ignores the defaults file' do
      expect(@config_files).to_not include("#{check_dir}/#{check_defaults_file}")
    end
  end

  describe '#check_config' do
    before do
      subject = RubyUptime::UserConfig.instance
      @checks = subject.checks
    end

    it 'contains all the example check configs' do
      expect(@checks).to include('json-test')
      expect(@checks).to include('yml-erb-test')
      expect(@checks).to include('testland')
      expect(@checks).to include('testland-dev')
      expect(@checks).to include('testland-missing-name')
      expect(@checks).to include('testland-prod')
    end

    it 'merges checks with the default prioritizing the check settings' do
      check = @checks['testland']
      expect(check['name']).to eq('Testland Lab')
      expect(check['host']).to eq('config.lab.testland.auth0.com')
      expect(check['protocol']).to eq('https')
      expect(check['success_criteria']).to eq([{
        'body' => "OK",
        'status' => 200
      }])
      expect(check['endpoint']).to eq('/testall')
      # no user-defined frequency - will pick up system default
      expect(check['frequency']).to be_nil
    end

    it 'allowed for specified defaults' do
      dev_check = @checks['testland-dev']
      prod_check = @checks['testland-prod']

      expect(dev_check['protocol']).to eq('https')
      expect(dev_check['success_criteria']).to eq([{
        'status' => 200
      }])
      expect(dev_check['endpoint']).to eq('/testall')
      expect(dev_check['frequency']).to eq(60)
      expect(dev_check['headers']).to eq({'Host' => 'a0-1.config.lab.testland.auth0.com'})

      expect(prod_check['protocol']).to eq('https')
      expect(prod_check['success_criteria']).to eq([{
        'body' => "OK",
        'status' => 200
      }])
      expect(prod_check['endpoint']).to eq('/testall')
      expect(prod_check['frequency']).to eq(10)
    end
  end

end
