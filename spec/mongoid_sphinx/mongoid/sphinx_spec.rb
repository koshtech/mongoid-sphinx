require 'spec_helper'

class Model
  include Mongoid::Document
  include Mongoid::Sphinx

  field :title
  field :content
  field :type

  embeds_one :embedded_model

  before_create do
    self.title = Faker::Lorem.words(5).map(&:capitalize).join(' ')
    self.content = "<p>#{Faker::Lorem.paragraphs.join('</p><p>')}</p>"
    self.type = %w(type1 type2 type3).sample
  end

  search_index(:fields => [:title, :content], :attributes => {:type => String})
end

describe Mongoid::Sphinx do
  before { Model.delete_all }

  let!(:model) { Model.create! }

  it "has a title and content" do
    model.title.should be
    model.content.should be
  end

  it "only has one model in the database" do
    Model.count.should be == 1
  end

  describe "XML stream generation" do
    let(:doc) { REXML::Document.new(Model.generate_stream) }

    it "has a single root docset" do
      doc.elements.to_a('/docset').length.should be == 1
    end
    it "has a single schema in the docset" do
      doc.elements.to_a('/docset/schema').length.should be == 1
    end
    it "has two fields" do
      doc.elements.to_a('/docset/schema/field').map{ |f| f.attributes['name'] }.should be == %w(title content)
    end
    it "has attributes" do
      doc.elements.to_a('/docset/schema/attr').length.should be == 3
      doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['name'] }.should be == %w[class_name class_filter type]
      doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['type'] }.should be == %w[string int string]
    end
    it "has a single document" do
      doc.elements.to_a('/docset/document').length.should be == 1
      REXML::XPath.first(doc, '/docset/document[1]/class_name/text()').to_s.should be == 'Model'
      REXML::XPath.first(doc, '/docset/document[1]/title/text()').to_s.should_not be_empty
      REXML::XPath.first(doc, '/docset/document[1]/content/text()').to_s.should_not be_empty
      REXML::XPath.first(doc, '/docset/document[1]/type/text()').to_s.should_not be_empty
    end
  end
end
