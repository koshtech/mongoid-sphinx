# MongoidSphinx

## Fork info

This is a fork of a fork of http://github.com/burke/mongosphinx with many 
changes to simplify and support Mongoid. In the future I will attempt to 
generalize and remove activesupport dependency but at the moment this gem has
Rails 3 and project specific features.

## General info

The MongoidSphinx library implements an interface between MongoDB and Sphinx 
supporting Mongoid to automatically index objects in Sphinx. It tries to
act as transparent as possible: Just an additional method in Mongoid
and some Sphinx configuration are needed to get going.

## Prerequisites

MongoidSphinx needs gems Mongoid and Riddle as well as a running Sphinx
and a MongoDB installation. Just add this to your Gemfile:

    gem riddle
    gem mongoid
    gem mongoid-sphinx, :require => 'mongoid_sphinx', :git => 'https://github.com/totothink/mongoid-sphinx.git'

No additional configuraton is needed for interfacing with MongoDB: Setup is
done when Mongoid is able to talk to the MongoDB server.

## Rake Tasks

MongoidSphinx can now generate your configs and control indexer and searchd through rake 
tasks (many thanks to Pat Allen for his work on Thinking Sphinx here. Much of the code to 
make this happen is right out of TS). Here is a list of the available rake tasks:

    mongoid_sphinx:configure # creates a configuration file in congif/{environment}.sphinx.conf
    mongoid_sphinx:index     # indexes your data
    mongoid_sphinx:start     # starts searchd
    mongoid_sphinx:stop      # stops searchd
    mongoid_sphinx:restart   # stops then start searchd
    mongoid_sphinx:run_in_foreground   # runs searchd in foreground
    
There are also some shortcuts you can use. See lib/mongoid_sphinx/tasks.rb for the full list.

## Models

Use method _search_index_ to enable indexing of a model. You must provide a list of
attribute keys.

A side effect of calling this method is, that MongoidSphinx overrides the
default of letting MongoDB create new IDs: Sphinx only allows numeric IDs and
MongoidSphinx forces new objects with the name of the class, a hyphen and an
integer as ID (e.g. _Post-38497238_). Again: Only these objects are
indexed due to internal restrictions of Sphinx.

Sample:

    class Post
      include Mongoid::Sphinx

      field :title
      field :body
      field :created_at, :type => 'DateTime'
      field :comment_count, :type => 'Integer'

      search_index(:fields => [:title, :body], 
                   :attributes => [:created_at, :comment_count],
                   :options => {:stopwords => "#{Rails.root}/config/sphinx/stopwords.txt"})
    end

You must also create a config/sphinx.yml file with the host and port of your sphinxd process like so:

    development:
      address: localhost
      port: 3312
      
    staging:
      address: localhost
      port: 3312
      
    production:
      address: localhost
      port: 3312

## Queries

An additional instance method <tt>search</tt> is added for each
search indexed model. This method takes a Sphinx query like
`foo @title bar`, runs it within the context of the current class and returns
an Array of matching MongoDB documents.

Samples:

    Post.search('first')
    => [...]
    
    post = Post.search('this is @title post').first
    post.title
    => "First Post"
    post.class
    => Post

Additional options _:match_mode_, _:limit_ and
_:max_matches_ can be provided to customize the behavior of Riddle.
Option _:raw_ can be set to _true_ to do no lookup of the
document IDs but return the raw IDs instead.

Sample:

    Post.search('my post', :limit => 100)
    
You can also specify filters based on attributes. Here is the format:

    post = Post.search('first', :with => {:created_at => 1.day.ago..Time.now})
    post = Post.search('first', :without => {:created_at => 1.day.ago..Time.now})
    post = Post.search('first', :with => {:comment_count => [5,6]})

## Copyright

Copyright (c) 2010 RedBeard Tech. See LICENSE for details.
