# MongoidSphinx, a full text indexing extension for MongoDB/Mongoid using Sphinx.

module Mongoid
  module Sphinx
    extend ActiveSupport::Concern
    included do
      unless defined?(SPHINX_TYPE_MAPPING)
        SPHINX_TYPE_MAPPING = {
          'Date' => 'timestamp',
          'DateTime' => 'timestamp',
          'Time' => 'timestamp',
          'Float' => 'float',
          'Integer' => 'int',
          'BigDecimal' => 'float',
          'Boolean' => 'bool',
          'String' => 'string'
        }
      end

      cattr_accessor :search_fields
      cattr_accessor :search_attributes
      cattr_accessor :index_options
      cattr_accessor :sphinx_index

      set_callback :create, :before do
        sid = while true
          candidate = rand(2**63-2)+1
          break candidate if self.class.where(:sphinx_id => candidate).blank?
        end
        self.sphinx_id = sid
      end

      field :sphinx_id, :type => Integer
      index :sphinx_id, unique: true
    end

    def excerpts(words, options={})   
      fields = self.class.get_fields(self)
      values = MongoidSphinx::excerpts(
        words,
        fields.values,
        self.class.internal_sphinx_index.core_name,
        options)
      Hash[[fields.keys,values].transpose]
    end
    alias :sphinx_excerpts :excerpts

    module ClassMethods
      def search_index(options={})
        self.search_fields = options[:fields] || []
        self.search_attributes = {}
        self.index_options = options[:options] || {}
        options[:attributes].each do |attribute, type|
          self.search_attributes[attribute] = SPHINX_TYPE_MAPPING[type.to_s] || 'str2ordinal'
        end

        MongoidSphinx.context.add_indexed_model self
      end

      def internal_sphinx_index
        self.sphinx_index ||= MongoidSphinx::Index.new(self)
      end

      def has_sphinx_indexes?
        self.search_fields && self.search_fields.length > 0
      end

      def to_riddle
        self.internal_sphinx_index.to_riddle
      end

      def sphinx_stream
        STDOUT.sync = true # Make sure we really stream..
        puts generate_stream
      end

      def generate_stream
        xml = ['<?xml version="1.0" encoding="utf-8"?>']
        xml << '<sphinx:docset xmlns:sphinx="">'

        # Schema
        xml << '<sphinx:schema>'
        self.search_fields.each do |key, value|
          xml << "<sphinx:field name=\"#{key}\"/>"
        end
        xml << '<sphinx:attr name="class_name" type="string"/>'
        self.search_attributes.each do |key, value|
          xml << "<sphinx:attr name=\"#{key}\" type=\"#{value}\"/>"
        end
        xml << '</sphinx:schema>'

        self.sphinx_models.each do |document|
          sphinx_compatible_id = document.sphinx_id
          if !sphinx_compatible_id.nil? && sphinx_compatible_id > 0
            xml << "<sphinx:document id=\"#{sphinx_compatible_id}\">"
            xml << "<class_name>#{document.class.to_s}</class_name>"
            self.get_fields(document).each{ |key, value| xml << "<#{key}><![CDATA[[#{value}]]></#{key}>" if value.present? }
            self.get_attributes(document).each{ |key, value| xml << "<#{key}><![CDATA[[#{value}]]></#{key}>" }
            xml << '</sphinx:document>'
          end
        end
        xml << '</sphinx:docset>'
        xml.join("\n")
      end

      def get_attributes(document)
        {}.tap do |attributes|
        self.search_attributes.each do |key, type|
          next unless document.respond_to?(key.to_sym)
          value = document.send(key.to_sym)
          value = case type
            when 'bool'
              value ? 1 : 0
            when 'timestamp'
              value.is_a?(Date) ? value.to_time.to_i : value.to_i
            else
              if value.is_a?(Array)
                value.join(", ")
              elsif value.is_a?(Hash)
                value.values.join(" : ")
              else
                value.to_s
              end
            end
          attributes[key] = value
          end
        end
      end
      
      def get_fields(document)
        {}.tap do |fields|
          self.search_fields.each do |key|
            next unless document.respond_to?(key.to_sym)
            value = document.send(key.to_sym)
            value = if value.is_a?(Array)
              value.join(", ")
            elsif value.is_a?(Hash)
              value.values.join(" : ")
            else
              value.to_s
            end
            fields[key] = value
          end
        end
      end

      def search(query, options = {})
        options[:ids_only] = true
        ids = MongoidSphinx::search(query, options)
        return self.where(:sphinx_id.in => ids)
      end

      def search_ids(id_range, options = {})
        options[:ids_only] = true
        ids = MongoidSphinx::search_ids(id_range, options)
        return self.where(:sphinx_id.in => ids)
      end

      def sphinx_models
        self.embedded? ? [] : self.all
      end
    end
  end
end

