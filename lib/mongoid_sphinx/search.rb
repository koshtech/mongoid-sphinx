require 'ostruct'

module MongoidSphinx
  def self.default_client(options={})
    MongoidSphinx::Configuration.instance.client.tap do |client|
      client.match_mode = options[:match_mode] || :extended
      client.limit = options[:limit] if options.key?(:limit)
      client.max_matches = options[:max_matches] if options.key?(:max_matches)

      if options.key?(:sort_by)
        client.sort_mode = :extended
        client.sort_by = options[:sort_by]
      end

      client.filters << Riddle::Client::Filter.new('class_filter', [class_filter(options[:class])], false) if options.key?(:class)

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
    end
  end

  def self.class_filter(klass)
    Digest::MD5.hexdigest(klass.to_s)[0...16].hex
  end

  def self.search(query, options = {})
    client = default_client(options)
    results = client.query(query)
    process_results(results)
  end

  def self.excerpts(words, docs, index, options = {})
    client = default_client(options)
    client.excerpts(options.merge({words:words, docs:docs, index:index}))
  end

  def self.search_ids(id_range, options = {})
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
    # TODO: I cant get this to work, always returns no results
    # client.filters << Riddle::Client::Filter.new('class_name', options[:class].name.to_a, false) if options.key?(:class)

    results = client.query('*')
    process_results(results)
  end

  def self.process_results(results)
    if results and results[:status] == 0 and (matches = results[:matches])
      matches.map do |row|
        class_name = row.fetch(:attributes,{}).fetch('class_name',nil)
        OpenStruct.new(sphinx_id:row[:doc], sphinx_weight:row[:weight], class_name:class_name) if row[:doc]
      end.compact
    else
      []
    end
  end
end
