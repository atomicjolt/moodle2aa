module Moodle2AA::Moodle2Converter
  class GenericActivityConverter
    include ConverterHelper

    def initialize(moodle_course)
      @moodle_course = moodle_course
    end

    def convert(moodle_activity)
      url = "mod/#{moodle_activity.type}/view.php?id=#{moodle_activity.module_id}"
      report_add_warn(moodle_activity, LEARNING, "unknown_activity_type=#{moodle_activity.type}", url)

      canvas_page = Moodle2AA::CanvasCC::Models::Page.new
      canvas_page.identifier = generate_unique_identifier_for_activity(moodle_activity)
      canvas_page.page_name = moodle_activity.name
      canvas_page.workflow_state = 'active'
      canvas_page.editing_roles = 'teachers,students'
      canvas_page.body = generate_body(moodle_activity)
      canvas_page.workflow_state = workflow_state(moodle_activity.visible)
      canvas_page
    end

    private

    def parse_files_from_course(moodle_activity)
      @moodle_course.files.select { |f| moodle_activity.file_ids.include? f.id }
    end

    def generate_body(moodle_activity)
      #TODO Do something better  for unconvertible activites.
      html = "<h2>#{moodle_activity.name}</h2>"
      html += '<dl>'
      html += 'This content could not be converted.'
      html += '</dl>'
      html
    end


  end
end