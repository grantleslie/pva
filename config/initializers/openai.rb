# config/initializers/openai.rb

#require "openai"

#OpenAI.configure do |config|
#  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
#  config.admin_token = ENV.fetch("OPENAI_ADMIN_TOKEN") # Optional, used for admin endpoints, created here: https://platform.openai.com/settings/organization/admin-keys
#  config.organization_id = ENV.fetch("OPENAI_ORGANIZATION_ID") 
#  config.log_errors = true
  # Optional:
  # config.organization_id = ENV["OPENAI_ORG_ID"]
  # config.request_timeout = 120
#end

#OPENAI_CLIENT = OpenAI::Client.new