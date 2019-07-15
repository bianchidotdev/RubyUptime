FactoryBot.define do
    factory :check do
      name { 'testland' }
      uri  { 'https://config.lab.testland.auth0.com/testall' }
      next_time { false }
      last_time { nil }
      valid { true }
    end
  end