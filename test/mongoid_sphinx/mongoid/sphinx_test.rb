require 'test_helper.rb'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'

require 'active_support/all'
require 'mongoid_sphinx/mongoid/sphinx.rb'

class Model
  def self.set_callback(*args);  end
  def self.field(*args); end
  def self.index(*args); end

  include Mongoid::Sphinx
end

describe Mongoid::Sphinx do

  before do
    @model = Model.new
  end

  it "can be created with no arguments" do
    Array.new.must_be_instance_of Array
  end

  it "can be created with a specific size" do
    Array.new(10).size.must_equal 10
  end
end
