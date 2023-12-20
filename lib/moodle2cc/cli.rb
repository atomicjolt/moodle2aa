require 'thor'
require 'pathname'
require 'progress_bar'

module Moodle2CC
  class CLI < Thor
    def self.shared_options
      method_option :format,                     :type => :string,  :default => 'cc'
      method_option :generate_archive,           :type => :boolean, :default => true
      method_option :generate_report,            :type => :boolean, :default => false
      method_option :version,                    :type => :string, :default =>  ''
      method_option :convert_unknown_qtypes,     :type => :boolean, :default => true
      method_option :convert_unknown_activities, :type => :boolean, :default => true
      method_option :group_by_quiz_page, :type => :boolean, :default => true
    end

    desc "migrate MOODLE_BACKUP_ZIP EXPORT_DIR", "Migrates Moodle backup ZIP to IMS Common Cartridge package"
    long_desc <<-LONGDESC
       Migrates Moodle backup ZIP to IMS Common Cartridge package

       With --generate-archive=false option, no CC archive is generated.
       With --generate-report=false option, no CSV migration report is generated
       With --convert-unknown-qtypes=false option, unknown question types are converted to text questions
       With --convert-unknown-activities=false option, unknown activity types are converted to pages
    LONGDESC
    shared_options
    def migrate(source, destination)
      migrator = Moodle2CC::Migrator.new source, destination, options
      migrator.migrate
      if migrator.respond_to?(:imscc_path)
        puts "#{source} converted to #{migrator.imscc_path}" if options[:generate_archive]
      end
      if migrator.last_error != nil
        exit 1
      end
    end

    desc "bulkmigrate MOODLE_BACKUP_DIR1 MOODLE_BACKUP_DIR2 ... EXPORT_DIR",
         "Migrates all Moodle backups in the specified backup directories to IMS Common Catridge packages"
    long_desc <<-LONGDESC
       Migrates all Moodle backups in the specified backup directories to IMS Common Catridge packages

       With --generate-archive=false option, no CC archive is generated
       With --generate-report=false option, no CSV migration report is generated
       With --concat-reports=false option, new CSV migration report for each course instead of concatenating them into one CSV
       With --convert-unknown-qtypes=false option, unknown question types are converted to text questions
       With --convert-unknown-activities=false option, unknown activity types are converted to pages
    LONGDESC
    shared_options
    method_option :concat_reports, :type => :boolean, :default => true
    def bulkmigrate(*sources, destination)
      if options["concat_reports"]
        # Set a timestamp to be used as part of the name of the bulk migration report CSV file
        #Moodle2CC::MigrationReport.launchtime = DateTime.now
      end

      numbackups = 0
      sources.each do |source_folder|
        next unless File.directory? source_folder
        numbackups += Pathname.new(source_folder).children.select { |child| child.directory? }.size
      end
      bar = ProgressBar.new(numbackups)

      sources.each do |source_folder|
        next unless File.directory? source_folder
        Pathname.new(source_folder).children.select { |child| child.directory? }.collect { |backup|
          puts "Converting #{backup}"
          migrator = Moodle2CC::Migrator.new backup, destination, options
          migrator.migrate
          #puts "#{backup} converted to #{migrator.imscc_path}" if options[:generate_archive]
          bar.increment!
        }
      end
    end
  end
end
