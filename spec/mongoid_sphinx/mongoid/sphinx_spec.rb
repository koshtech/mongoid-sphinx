require 'spec_helper'

class DoubleEmbeddedModel
  include Mongoid::Document
  include Mongoid::Sphinx

  field :title

  embedded_in :embedded_model

  before_create do
    self.title = Faker::Lorem.words(5).map(&:capitalize).join(' ')
  end

  search_index(:fields => [:title], :attributes => {})

  def self.sphinx_models
    Model.all.map(&:embedded_model).compact.flatten.map(&:double_embedded_model).compact.flatten
  end
end

class EmbeddedModel
  include Mongoid::Document
  include Mongoid::Sphinx

  field :title

  embedded_in :model
  embeds_one :double_embedded_model

  before_create do
    self.build_double_embedded_model
  end

  search_index(:fields => [:title], :attributes => {})

  def self.sphinx_models
    Model.all.map(&:embedded_model).flatten
  end
end

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
    self.embedded_model = EmbeddedModel.new(
      title:Faker::Lorem.words(5).map(&:capitalize).join(' '),
      double_embedded_model:DoubleEmbeddedModel.new(
        title:Faker::Lorem.words(5).map(&:capitalize).join(' '))
    )
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
      doc.elements.to_a('/docset/schema/attr').length.should be == 2
      doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['name'] }.should be == %w(class_name type)
      doc.elements.to_a('/docset/schema/attr').map{ |a| a.attributes['type'] }.should be == %w(string string)
    end
    it "has a single document" do
      doc.elements.to_a('/docset/document').length.should be == 1
      REXML::XPath.first(doc, '/docset/document[1]/class_name/text()').to_s.should be == 'Model'
      REXML::XPath.first(doc, '/docset/document[1]/title/text()').to_s.should_not be_empty
      REXML::XPath.first(doc, '/docset/document[1]/content/text()').to_s.should_not be_empty
      REXML::XPath.first(doc, '/docset/document[1]/type/text()').to_s.should_not be_empty
    end
  end

  describe "embedded stream generation" do
    let(:doc) { EmbeddedModel.generate_stream }
    specify { EmbeddedModel.sphinx_models.should be == [model.embedded_model] }
    specify { p doc }
  end

  describe "double embedded stream generation" do
    let(:doc) { DoubleEmbeddedModel.generate_stream }
    specify { DoubleEmbeddedModel.sphinx_models.should be == [model.embedded_model.double_embedded_model] }
    specify { p doc }
  end
end
