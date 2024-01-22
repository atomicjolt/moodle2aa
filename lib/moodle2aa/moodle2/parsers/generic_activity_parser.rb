module Moodle2AA::Moodle2::Parsers
  class GenericActivityParser
    include ParserHelper

    def initialize(backup_dir)
      @backup_dir = backup_dir
    end

    def parse(type)
      activity_dirs = activity_directories(@backup_dir, type)
      activity_dirs.map { |dir| parse_activity(dir, type) }
    end

    private

    def parse_activity(dir, type)
      activity = Moodle2AA::Moodle2::Models::GenericActivity.new
      activity_dir = File.join(@backup_dir, dir)
      File.open(File.join(activity_dir, type+".xml")) do |f|
        activity_xml = Nokogiri::XML(f)
        activity.id = activity_xml.at_xpath("/activity/#{type}/@id").value
        activity.module_id = activity_xml.at_xpath("/activity/@moduleid").value
        activity.name = parse_text(activity_xml, "/activity/#{type}/name")
        activity.intro = parse_text(activity_xml, "/activity/#{type}/intro")
        activity.intro_format = parse_text(activity_xml, "/activity/#{type}/introformat")
        activity.time_modified = parse_text(activity_xml, "/activity/#{type}/timemodified")
        activity.type = type;
      end
      parse_module(activity_dir, activity)

      activity
    end

  end

end