require_relative 'boot'

require 'rails/all'

#
# Rails5に対応前のgemからの警告が多いのでサイレントにします。
#
ActiveSupport::Deprecation.silenced = true

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.autoload_paths += %W(#{config.root}/lib)

    # load config/application.yml
    config_for(:application).each do |key, value|
      config.x.send("#{key}=", value)
    end
  end
end
