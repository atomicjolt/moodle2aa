module Moodle2AA
  class MigrationReport

    require 'csv'

    attr_accessor :moodle_course

    # edulevels
    TEACHING = "teaching"
    LEARNING = "learning"
    OTHER = "other"

    # Moodle site URL, if known.
    @@siteurl = '';

    # Migration report options
    # defaults are set for compatibility with built-in rspec tests
    @@options = { "generate_archive" => true,
                  "generate_report" => false,
                  "convert_unknown_qtypes" => false,
                  "convert_unknown_activities" => false,
    }

    def self.options()
      @@options
    end

    def self.options=(options)
      @@options = @@options.merge(options)
    end
    
    def self.source()
      @@source
    end

    def self.source=(source)
      @@source = source
    end

    def self.siteurl=(url)
      @@siteurl = url
    end

    def self.generate_archive?()
      @@options["generate_archive"]
    end

    def self.generate_report?()
      @@options["generate_report"]
    end

    def self.convert_unknown_qtypes?()
      @@options["convert_unknown_qtypes"]
    end

    def self.convert_unknown_activities?()
      @@options["convert_unknown_activities"]
    end
    
    def self.group_by_quiz_page?()
      @@options["group_by_quiz_page"]
    end

    def self.create(out_dir, moodle_course)
      Thread.current[:__moodle2aa_migration_report__] = MigrationReport.new(out_dir, moodle_course)
    end

    def self.close()
      Thread.current[:__moodle2aa_migration_report__].csvfile.close if Thread.current[:__moodle2aa_migration_report__].csvfile
      Thread.current[:__moodle2aa_migration_report__] = nil
    end

    def self.instance()
      Thread.current[:__moodle2aa_migration_report__]
    end

    def self.add(model, edulevel, message, url, name)
      instance = self.instance || return
      instance.add(model, edulevel, message, url, name)
    end

    def self.moodle_course_id()
      instance = self.instance
      if instance && instance.moodle_course
        instance.moodle_course.course_id
      else
        0
      end
    end

    # Instance methods follow.  The general API is via class methods (above).

    def initialize(out_dir, moodle_course)
      @moodle_course = moodle_course
      if MigrationReport.generate_report?
        @csvfile = CSV.open File.join(out_dir, filename), "wb"
        @csvfile << ["model", "edulevel", "message", "url", "name"]
      else
        @csvfile = nil
      end
    end


    def csvfile()
      return @csvfile
    end

    def filename
      title = @moodle_course.fullname.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
        gsub(/([a-z\d])([A-Z])/, '\1_\2').
        gsub(/[\/|\.]/, '_').
        tr('- ', '_').downcase.
        gsub(/_{2,}/, '_')
      "#{title}-report.csv"
    end

    def add(model, edulevel, message, url, name)
      return unless MigrationReport.generate_report?
      @csvfile << [modelname(model), edulevel, message, moodleurl(url), name]
    end

    def modelname(model)
      if model.is_a? String
        model
      else
        model.class.to_s.downcase.gsub(/^.*::/, '')
      end
    end

    def moodleurl(url)
      if (url.is_a? String) && url.length > 0
        @@siteurl+'/'+url
      else
        ""
      end
    end
  end
end
