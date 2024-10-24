module Moodle2AA
  module Moodle2Converter::ConverterHelper
    INTRO_SUFFIX = '_book_intro'
    CHAPTER_SUFFIX = '_chapter'
    FOLDER_SUFFIX = '_folder'
    PAGE_SUFFIX = '_page'
    ASSESSMENT_SUFFIX = '_assessment'
    CHOICE_ASSESSMENT_SUFFIX = '_choice_assessment'
    FEEDBACK_ASSESSMENT_SUFFIX = '_feedback_assessment'
    QUESTIONNAIRE_ASSESSMENT_SUFFIX = '_questionnaire_assessment'
    ASSIGNMENT_SUFFIX = '_assignment'
    COURSE_SUFFIX = '_course'
    DISCUSSION_SUFFIX = '_discussion'
    FILE_SUFFIX = '_file'
    QUESTION_BANK_SUFFIX = '_question_bank'
    MODULE_SUFFIX = '_module'
    GLOSSARY_SUFFIX = '_glossary'
    SUMMARY_PAGE_SUFFIX = '_summary_page'
    EXTERNAL_URL_SUFFIX = '_external_url'
    LTI_SUFFIX = '_lti'
    GENERIC_ACTIVITY_SUFFIX = '_generic_activity'

    ACTIVITY_LOOKUP = {
      Moodle2::Models::Page => {suffix: PAGE_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::Wiki => {suffix: PAGE_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::Assignment => {suffix: ASSIGNMENT_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_ASSIGNMENT},
      Moodle2::Models::Folder => {suffix: FOLDER_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::Forum => {suffix: DISCUSSION_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_DISCUSSION_TOPIC},
      Moodle2::Models::Book => {suffix: INTRO_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::BookChapter => {suffix: CHAPTER_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::Quizzes::Quiz => {suffix: ASSESSMENT_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_QUIZ},
      Moodle2::Models::Choice => {suffix: CHOICE_ASSESSMENT_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_QUIZ},
      Moodle2::Models::Feedback => {suffix: FEEDBACK_ASSESSMENT_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_QUIZ},
      Moodle2::Models::Questionnaire => {suffix: QUESTIONNAIRE_ASSESSMENT_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_QUIZ},
      Moodle2::Models::Section => {suffix: SUMMARY_PAGE_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::Label => {suffix: nil, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_CONTEXT_MODULE_SUB_HEADER},
      Moodle2::Models::Glossary => {suffix: GLOSSARY_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE},
      Moodle2::Models::ExternalUrl => {suffix: EXTERNAL_URL_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_EXTERNAL_URL},
      Moodle2::Models::Resource => {suffix: nil, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_ATTACHMENT},
      Moodle2::Models::Lti => {suffix: LTI_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_CONTEXT_EXTERNAL_TOOL},
      Moodle2::Models::GenericActivity => {suffix: GENERIC_ACTIVITY_SUFFIX, content_type: CanvasCC::Models::ModuleItem::CONTENT_TYPE_WIKI_PAGE}
    }

    MAX_TITLE_LENGTH = 250

    def generate_unique_resource_path(base_path, readable_name, file_extension = 'html')
      file_name_suffix = readable_name ? Moodle2AA::CanvasCC::Models::Page.convert_name_to_url(readable_name) : ''
      ext = file_extension ? ".#{file_extension}" : ''
      File.join(base_path, generate_unique_identifier(), "#{file_name_suffix}#{ext}")
    end

    def generate_unique_identifier
      "m2#{SecureRandom.uuid.gsub('-', '')}"
    end

    def get_unique_identifier_for_activity(activity)
      # use when we want to retrieve an existing id, not generate a new one
      id = Moodle2Converter::Migrator.activity_id_map[activity.hash]
      unless id
        Moodle2AA::OutputLogger.logger.info "could not find matching id for #{activity.inspect}"
        id = generate_unique_identifier_for_activity(activity)
      end
      id
    end

    def generate_unique_identifier_for_activity(activity)
      if lookup = ACTIVITY_LOOKUP[activity.class]
        unique_id = generate_unique_identifier_for(activity.id, lookup[:suffix])
        Moodle2Converter::Migrator.activity_id_map[activity.hash] = unique_id
        unique_id
      else
        raise "Unknown activity type: #{activity.class}"
      end
    end

    def generate_unique_identifier_for(id, suffix = nil)
      unique_id = "m2#{Digest::MD5.hexdigest(id.to_s)}#{suffix}"
      id_set = Moodle2Converter::Migrator.unique_id_set
      if id_set.include?(unique_id)
        # i was under the impression that moodle ids would be unique themselves
        # but i have been apparently misinformed
        original_id = unique_id
        index = 0
        while id_set.include?(unique_id)
          index += 1
          unique_id = "#{original_id}#{index}"
        end
      end
      id_set << unique_id
      unique_id
    end

    def activity_content_type(activity)
      if lookup = ACTIVITY_LOOKUP[activity.class]
        lookup[:content_type]
      else
        raise "Unknown activity type: #{activity.class}"
      end
    end

    def workflow_state(moodle_visibility)
      moodle_visibility ? CanvasCC::Models::WorkflowState::ACTIVE : CanvasCC::Models::WorkflowState::UNPUBLISHED
    end

    def truncate_text(text, max_length = nil, ellipsis = '...')
      max_length ||= MAX_TITLE_LENGTH
      return text if !text || text.length <= max_length

      actual_length = max_length - ellipsis.length

      # First truncate the text down to the bytes max, then lop off any invalid
      # unicode characters at the end.
      truncated = text[0,actual_length][/.{0,#{actual_length}}/mu]
      truncated + ellipsis
    end

    LEARNING = Moodle2AA::MigrationReport::LEARNING
    TEACHING = Moodle2AA::MigrationReport::TEACHING
    OTHER = Moodle2AA::MigrationReport::OTHER

    def report_add_warn(model, edulevel, message, url=nil, name=nil)
      if !name && model.respond_to?(:name)
        name = model.name
      end
      if !url && model.respond_to?(:module_id)
        mod = model.class.to_s.downcase.gsub(/^.*::/, '')
        url = "mod/#{mod}/view.php?id=#{model.module_id}"
      end
      Moodle2AA::MigrationReport.add(model, edulevel, message, url, name)
    end

    def report_current_course_id()
      Moodle2AA::MigrationReport.moodle_course_id
    end

  end
end
