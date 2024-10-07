require 'json'

module Moodle2AA::Learnosity
  module Writers
    require_relative 'writers/export'
    require_relative 'writers/file_writer'
    require_relative 'writers/atomicassessments'
    require_relative 'writers/json'
  end
end
