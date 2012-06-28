module Moodle2CC::CC
  class Course
    include CCHelper

    attr_accessor :id, :title, :course_code, :start_at, :is_public, :syllabus_body

    def initialize(course)
      @course = course

      @id = course.id
      @title = course.fullname
      @course_code = course.shortname
      @start_at = ims_datetime(Time.at(course.startdate))
      @is_public = course.visible
      @syllabus_body = course.sections.first.summary
    end

    def identifier
      create_key(id, 'course_')
    end

    def create_resource_node(resources_node)
      syllabus_href = File.join(COURSE_SETTINGS_DIR, SYLLABUS)
      resources_node.resource(
        :intendeduse => 'syllabus',
        :href => syllabus_href,
        :type => LOR,
        :identifier => create_key(syllabus_href, 'resource_')
      ) do |resource_node|
        resource_node.file(:href => File.join(COURSE_SETTINGS_DIR, SYLLABUS))
        resource_node.file(:href => File.join(COURSE_SETTINGS_DIR, COURSE_SETTINGS))
        resource_node.file(:href => File.join(COURSE_SETTINGS_DIR, FILES_META))
        resource_node.file(:href => File.join(COURSE_SETTINGS_DIR, MODULE_META))
        resource_node.file(:href => File.join(COURSE_SETTINGS_DIR, ASSIGNMENT_GROUPS))
      end
    end

    def create_files(export_dir)
      create_syllabus_file(export_dir)
      create_course_settings_xml(export_dir)
      create_files_meta_xml(export_dir)
      create_assignment_groups_xml(export_dir)
      create_module_meta_xml(export_dir)
    end

    def create_syllabus_file(export_dir)
      template = File.expand_path('../templates/syllabus.html.erb', __FILE__)
      path = File.join(export_dir, COURSE_SETTINGS_DIR, SYLLABUS)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        erb = ERB.new(File.read(template))
        file.write(erb.result(binding))
      end
    end

    def create_course_settings_xml(export_dir)
      path = File.join(export_dir, COURSE_SETTINGS_DIR, COURSE_SETTINGS)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        document = Builder::XmlMarkup.new(:target => file, :indent => 2)
        document.instruct!
        document.course(
          :identifier => identifier,
          'xsi:schemaLocation' => "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd",
          'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
          'xmlns' => "http://canvas.instructure.com/xsd/cccv1p0"
        ) do |course_node|
          course_node.title @title
          course_node.course_code @course_code
          course_node.start_at @start_at
          course_node.is_public @is_public
          course_node.license 'private'
        end
      end
    end

    def create_module_meta_xml(export_dir)
      path = File.join(export_dir, COURSE_SETTINGS_DIR, MODULE_META)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        document = Builder::XmlMarkup.new(:target => file, :indent => 2)
        document.instruct!
        document.modules(
          'xsi:schemaLocation' => "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd",
          'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
          'xmlns' => "http://canvas.instructure.com/xsd/cccv1p0"
        ) do |modules_node|
          @course.sections.each do |section|
            modules_node.module(:identifier => create_key(section.id, 'section_')) do |module_node|
              module_node.title "week #{section.number}"
              module_node.position section.number
              module_node.require_sequential_progress false
              module_node.items do |items_node|
                section.mods.each_with_index do |mod,index|
                  next if mod.instance.mod_type == 'assignment'
                  items_node.item(:identifier => create_key(mod.instance_id, 'mod_')) do |item_node|
                    item_node.title mod.instance.name
                    item_node.position index
                    item_node.new_tab ''
                    item_node.indent mod.indent
                    case mod.instance.mod_type
                    when 'resource'
                      if mod.instance.type == 'file'
                        item_node.content_type 'ExternalUrl'
                        item_node.url mod.instance.reference
                        item_node.identifierref create_key(mod.instance.id, 'resource_')
                      else
                        item_node.content_type 'WikiPage'
                        item_node.identifierref create_key(mod.instance.id, 'resource_')
                      end
                    when 'forum'
                      item_node.content_type 'DiscussionTopic'
                      item_node.identifierref create_key(mod.instance.id, 'resource_')
                    when 'label'
                      item_node.content_type 'ContextModuleSubHeader'
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    def create_assignment_groups_xml(export_dir)
      path = File.join(export_dir, COURSE_SETTINGS_DIR, ASSIGNMENT_GROUPS)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        document = Builder::XmlMarkup.new(:target => file, :indent => 2)
        document.instruct!
        document.assignmentGroups(
          'xsi:schemaLocation' => "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd",
          'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
          'xmlns' => "http://canvas.instructure.com/xsd/cccv1p0"
        ) do |assignment_groups_node|
          @course.sections.each do |section|
            next unless section.mods.select { |mod| mod.instance.mod_type == "assignment" }.length > 0
            assignment_groups_node.assignmentGroup(:identifier => create_key(section.id, "assignment_group_")) do |assignment_group_node|
              assignment_group_node.title "Week #{section.number}"
            end
          end
        end
      end
    end

    def create_files_meta_xml(export_dir)
      path = File.join(export_dir, COURSE_SETTINGS_DIR, FILES_META)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |file|
        document = Builder::XmlMarkup.new(:target => file, :indent => 2)
        document.instruct!
        document.filesMeta(
          'xsi:schemaLocation' => "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd",
          'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
          'xmlns' => "http://canvas.instructure.com/xsd/cccv1p0")
      end
    end

  end
end
