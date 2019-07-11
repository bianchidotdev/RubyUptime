module AppConfig
  module CheckDefaults
    PROTOCOL = 'https'
    FREQUENCY = 10
    ENDPOINT = '/testall'
    success_criteria {
      status = 200,
      body = 'OK'
    }
  end  
end
