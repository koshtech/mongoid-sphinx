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
        puts '<sphinx:attr name="classname" type="string"/>'
        self.search_attributes.each do |key, value|
          puts "<sphinx:attr name=\"#{key}\" type=\"#{value}\"/>"
        end
        puts '</sphinx:schema>'

        self.all.entries.each do |document|
          sphinx_compatible_id = document.sphinx_id
          if !sphinx_compatible_id.nil? && sphinx_compatible_id > 0
            puts "<sphinx:document id=\"#{sphinx_compatible_id}\">"

            puts "<classname>#{self.to_s}</classname>"
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
        client = MongoidSphinx::Configuration.instance.client

        client.match_mode = options[:match_mode] || :extended
        client.limit = options[:limit] if options.key?(:limit)
        client.max_matches = options[:max_matches] if options.key?(:max_matches)

        if options.key?(:sort_by)
          client.sort_mode = :extended
          client.sort_by = options[:sort_by]
        end

        # client.filters << Riddle::Client::Filter.new('classname', [self.to_s], false)

        if options.key?(:with)
          options[:with].each do |key, value|
            client.filters << Riddle::Client::Filter.new(key.to_s, value.is_a?(Range) ? value : value.to_a, false)
          end
        end

        if options.key?(:without)
          options[:without].each do |key, value|
            client.filters << Riddle::Client::Filter.new(key.to_s, value.is_a?(Range) ? value : value.to_a, true)
          end
        end

        result = client.query(query)

        if result and result[:status] == 0 and (matches = result[:matches])
          ids = matches.collect do |row|
            row[:doc]
          end.compact

          return ids if options[:raw] or ids.empty?
          return self.where( :sphinx_id.in => ids )
        else
          return []
        end
      end
    end

    def search_ids(id_range, options = {})
      client = MongoidSphinx::Configuration.instance.client

      if id_range.is_a?(Range)
        client.id_range = id_range
      elsif id_range.is_a?(Fixnum)
        client.id_range = id_range..id_range
      else
        return []
      end

      client.match_mode = :extended
      client.limit = options[:limit] if options.key?(:limit)
      client.max_matches = options[:max_matches] if options.key?(:max_matches)
      client.filters << Riddle::Client::Filter.new('classname', [self.to_s], false)

      result = client.query("*")

      if result and result[:status] == 0 and (matches = result[:matches])
        ids = matches.collect do |row|
          row[:doc]
        end.compact

        return ids if options[:raw] or ids.empty?
        return self.where( :sphinx_id.in => ids )
      else
        return false
      end
    end

  end
end

