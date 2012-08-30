require 'bundler'
Bundler.require(:default, :development)

require 'active_support/all'
require 'mongoid'
require 'mongoid_sphinx.rb'

require 'rexml/document'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db('mongoid_sphinx_test')
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.filter_run :wip => true
  config.run_all_when_everything_filtered = true
end
