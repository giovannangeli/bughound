# config/initializers/openai.rb

require 'openai'

# Ne configure OpenAI que si la clé est présente
if ENV["OPENAI_API_KEY"].present?
  OpenAI.configure do |config|
    config.access_token = ENV.fetch("OPENAI_API_KEY")
  end
end