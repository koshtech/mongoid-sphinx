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

      set_callback :create, :after do
        sid = while true
          candidate = rand(2**63-2)+1
          break candidate if self.class.where(:sphinx_id => candidate).blank?
        end
        self.update_attributes(:sphinx_id => sid)
      end

      field :sphinx_id, :type => Integer
      index :sphinx_id, unique: true

    end

    module ClassMethods

      def search_index(options={})
        self.search_fields = options[:fields]
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

        puts '<?xml version="1.0" encoding="utf-8"?>'
        puts '<sphinx:docset>'

        # Schema
        puts '<sphinx:schema>'
        self.search_fields.each do |key, value|
          puts "<sphinx:field name=\"#{key}\"/>"
        end
        puts '<sphinx:attr name="class_name" type="string"/>'
        self.search_attributes.each do |key, value|
          puts "<sphinx:attr name=\"#{key}\" type=\"#{value}\"/>"
        end
        puts '</sphinx:schema>'

        self.all.each do |document|
          sphinx_compatible_id = document.sphinx_id
          if !sphinx_compatible_id.nil? && sphinx_compatible_id > 0
            puts "<sphinx:document id=\"#{sphinx_compatible_id}\">"
            puts "<class_name>#{self.to_s}</class_name>"
            self.search_fields.each do |key|
              if document.respond_to?(key.to_sym)
                value = document.send(key.to_sym)
                if value.is_a?(Array)
                  puts "<#{key}><![CDATA[[#{value.join(", ")}]]></#{key}>"
                elsif value.is_a?(Hash)
                  entries = []
                  value.to_a.each do |entry|
                    entries << entry.join(" : ")
                  end
                  puts "<#{key}><![CDATA[[#{entries.join(", ")}]]></#{key}>"
                else
                  puts "<#{key}><![CDATA[[#{value}]]></#{key}>"
                end
              end
            end
            self.search_attributes.each do |key, type|
              if document.respond_to?(key.to_sym)
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
                      entries = []
                      value.to_a.each do |entry|
                        entries << entry.join(" : ")
                      end
                      entries.join(", ")
                    else
                      value.to_s
                    end
                end
                puts "<#{key}>#{value}</#{key}>"
              end
            end
            puts '</sphinx:document>'
          end
        end
        puts '</sphinx:docset>'
      end

      def search(query, options = {})
        options(:class => self)
        ids = MongoidSphinx::search(query, options)
        return ids if options[:raw] or ids.empty?
        return self.where( :sphinx_id.in => ids )
      end

      def search_ids(id_range, options = {})
        options(:class => self)
        ids = MongoidSphinx::search_ids(id_range, options)
        return ids if options[:raw] or ids.empty?
        return self.where( :sphinx_id.in => ids )
      end

    end
  end
end

