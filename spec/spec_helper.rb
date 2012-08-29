require 'bundler'
Bundler.require(:default, :development)

require 'active_support/all'
require 'mongoid'
require 'mongoid_sphinx.rb'

require 'rexml/document'

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db('mongoid_sphinx_test')
end
