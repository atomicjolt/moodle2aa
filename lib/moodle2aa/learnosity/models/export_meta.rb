module Moodle2AA::Learnosity::Models
  class ExportMeta
    include JsonWriter

    attr_accessor :moodle_url, :moodle_course_name, :convert_date, :version

  end
end

