require 'test_helper.rb'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'

require 'active_support/all'
require 'mongoid'
require 'mongoid_sphinx.rb'

require "rexml/document"

Mongoid.configure do |config|
  config.master = Mongo::Connection.new.db("mongoid_sphinx_test")
end

class Model
  include Mongoid::Document
  include Mongoid::Sphinx

  field :title
  field :content
  field :type

  before_create do
    self.title = Faker::Lorem.words(5).map(&:capitalize).join(' ')
    self.content = "<p>#{Faker::Lorem.paragraphs.join('</p><p>')}</p>"
    self.type = %w(type1 type2 type3).shuffle.pop
  end

  search_index(:fields => [:title, :content], :attributes => {:type => String})
end

describe Mongoid::Sphinx do

  before do
    Model.delete_all
    @model = Model.create!
  end

  it "has a title and content" do
    @model.title.wont_be_nil
    @model.content.wont_be_nil
  end

  it "only has one model in the database" do
    Model.count.must_equal 1
  end

  describe "XML stream generation" do

    before do
      @doc ||= REXML::Document.new(Model.generate_stream)
    end

    it "has a single root docset" do
      @doc.elements.to_a('/docset').length.must_equal 1
    end
    it "has a single schema in the docset" do
      @doc.elements.to_a('/docset/schema').length.must_equal 1
    end
    it "has two fields" do
      @doc.elements.to_a('/docset/schema/field').map{ |f| f.attributes['name'] }.must_equal %w(title content)
    end
    it "has attributes" do
      @doc.elements.to_a('/docset/schema/attr').length.must_equal 2
      @doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['name'] }.must_equal %w(class_name type)
      @doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['type'] }.must_equal %w(string string)
    end
    it "has a single document" do
      @doc.elements.to_a('/docset/document').length.must_equal 1
      REXML::XPath.first(@doc, '/docset/document[1]/class_name/text()').to_s.must_equal 'Model'
      REXML::XPath.first(@doc, '/docset/document[1]/title/text()').to_s.wont_be_empty
      REXML::XPath.first(@doc, '/docset/document[1]/content/text()').to_s.wont_be_empty
      REXML::XPath.first(@doc, '/docset/document[1]/type/text()').to_s.wont_be_empty
    end

  end

end
