
require 'json'

module Moodle2AA::Learnosity::Writers
  class Json

    def initialize(learnosity, moodle_course)
      @moodle_course = moodle_course
      @learnosity = learnosity
    end

    def create(out_dir)
      out_file = File.join(out_dir, filename)

      File.open(out_file,"w") do |f|
        f.write(@learnosity.to_json)
      end

      out_file
    end

    def filename
      source = File.basename Moodle2AA::MigrationReport.source
      source = source.gsub(/(\.zip|\.mbz)/,'')
      "#{source}-learnosity.json"
      #title = @moodle_course.fullname.gsub(/::/, '/').
      #gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
      #gsub(/([a-z\d])([A-Z])/, '\1_\2').
      #gsub(/[\/|\.]/, '_').
      #tr('- ', '_').downcase.
      #gsub(/_{2,}/, '_')
      #"#{title}-learnosity.zip"
    end
  end
end
