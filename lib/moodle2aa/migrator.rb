require 'zip'

module Moodle2AA
  class Migrator

    attr_accessor :last_error

    MOODLE_1_9 = '1.9'
    MOODLE_2 = '2'

    def initialize(source, destination, options={})
      @source = source
      @destination = destination
      @format = options['format'] || 'cc'
      Moodle2AA::Logger.logger = options['logger'] || ::Logger.new(STDOUT)
      Moodle2AA::MigrationReport.siteurl = options['siteurl'] || ''
      Moodle2AA::MigrationReport.options = options
      Moodle2AA::MigrationReport.source = @source
      raise(Moodle2AA::Error, "'#{@source}' does not exist") unless File.exist?(@source)
      raise(Moodle2AA::Error, "'#{@destination}' is not a directory") unless File.directory?(@destination)
      raise(Moodle2AA::Error, "'#{@format}' is not a valid format. Please use 'cc' or 'canvas'.") unless ['cc', 'canvas'].include?(@format)
      @converter_class = @format == 'cc' ? Moodle2AA::CC::Converter : Moodle2AA::Canvas::Converter
    end

    def migrate
      @last_error = nil
      case moodle_version
        when MOODLE_1_9
          migrate_moodle_1_9
        when MOODLE_2
          migrate_moodle_2
      end
    rescue StandardError => error
      raise
      @last_error = error
      Moodle2AA::Logger.add_warning 'error migrating content', error
    end

    def imscc_path
      if @converter
        @converter.imscc_path
      end
    end

    def migrate_moodle_1_9
      puts "SKIPPING MOODLE 1.9 ARCHIVE"
      return
      backup = Moodle2AA::Moodle::Backup.read @source
      @converter = @converter_class.new backup, @destination
      @converter.convert
    end

    def migrate_moodle_2
      @converter = Moodle2AA::Moodle2Converter::Migrator.new(@source, @destination)
      @converter.migrate
    end

    private

    def moodle_version
      if File.directory?(@source)
        if File.exist?(File.join(@source, 'moodle_backup.xml'))
          MOODLE_2
        elsif File.exist?(File.join(@source, 'moodle.xml'))
          MOODLE_1_9
        end
      else
        type = `file "#{@source}"`
        if /gzip/.match(type)
          files = `tar tzf "#{@source}"`
          if files.match(/^(\.|)moodle_backup\.xml/)
            MOODLE_2
          else
            MOODLE_1_9
          end
        else
          Zip::File.open(@source) do |zipfile|
            if zipfile.find_entry('moodle_backup.xml')
              MOODLE_2
            elsif zipfile.find_entry('moodle.xml')
              MOODLE_1_9
            end
          end
        end
      end
    end

  end
end
