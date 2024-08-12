require 'builder'
require 'cgi'
require 'erb'
require 'fileutils'
require 'happymapper'
require 'logger'
require 'nokogiri'
require 'ostruct'
require 'rdiscount'
require 'uri'
require 'securerandom'

require 'moodle2aa/error'
require 'moodle2aa/logger'
require 'moodle2aa/migration_report'
require 'moodle2aa/migrator'

require 'moodle2aa/moodle2'

require 'moodle2aa/learnosity/converters.rb'
require 'moodle2aa/learnosity/models.rb'
require 'moodle2aa/learnosity/writers.rb'
require 'moodle2aa/learnosity/migrator.rb'

module Moodle2AA
  class OpenStruct < ::OpenStruct
    if defined? id
      undef id
    end
  end

  autoload :ResourceFactory, 'moodle2aa/resource_factory'

  autoload :OutputLogger, 'moodle2aa/output_logger'

  module CC
    autoload :Assessment, 'moodle2aa/cc/assessment'
    autoload :Assignment, 'moodle2aa/cc/assignment'
    autoload :CCHelper, 'moodle2aa/cc/cc_helper'
    autoload :Converter, 'moodle2aa/cc/converter'
    autoload :Course, 'moodle2aa/cc/course'
    autoload :DiscussionTopic, 'moodle2aa/cc/discussion_topic'
    autoload :Label, 'moodle2aa/cc/label'
    autoload :Question, 'moodle2aa/cc/question'
    autoload :Resource, 'moodle2aa/cc/resource'
    autoload :WebContent, 'moodle2aa/cc/web_content'
    autoload :WebLink, 'moodle2aa/cc/web_link'
    autoload :Wiki, 'moodle2aa/cc/wiki'
  end
  module Canvas
    autoload :Assessment, 'moodle2aa/canvas/assessment'
    autoload :Assignment, 'moodle2aa/canvas/assignment'
    autoload :Converter, 'moodle2aa/canvas/converter'
    autoload :Course, 'moodle2aa/canvas/course'
    autoload :DiscussionTopic, 'moodle2aa/canvas/discussion_topic'
    autoload :Label, 'moodle2aa/canvas/label'
    autoload :Question, 'moodle2aa/canvas/question'
    autoload :QuestionBank, 'moodle2aa/canvas/question_bank'
    autoload :QuestionGroup, 'moodle2aa/canvas/question_group'
    autoload :Resource, 'moodle2aa/canvas/resource'
    autoload :WebContent, 'moodle2aa/canvas/web_content'
    autoload :WebLink, 'moodle2aa/canvas/web_link'
    autoload :Wiki, 'moodle2aa/canvas/wiki'
  end
  module Moodle
    autoload :Backup, 'moodle2aa/moodle/backup'
    autoload :Course, 'moodle2aa/moodle/course'
    autoload :GradeItem, 'moodle2aa/moodle/grade_item'
    autoload :Info, 'moodle2aa/moodle/info'
    autoload :Mod, 'moodle2aa/moodle/mod'
    autoload :Question, 'moodle2aa/moodle/question'
    autoload :QuestionCategory, 'moodle2aa/moodle/question_category'
    autoload :Section, 'moodle2aa/moodle/section'
  end
  module CanvasCC
    autoload :ImsManifestGenerator, 'moodle2aa/canvas_cc/ims_manifest_generator'
    autoload :CartridgeCreator, 'moodle2aa/canvas_cc/cartridge_creator'
    autoload :CourseSettingWriter, 'moodle2aa/canvas_cc/course_setting_writer'
    autoload :ModuleMetaWriter, 'moodle2aa/canvas_cc/module_meta_writer'
    autoload :FileMetaWriter, 'moodle2aa/canvas_cc/file_meta_writer'
    autoload :CanvasExportWriter, 'moodle2aa/canvas_cc/canvas_export_writer'
    autoload :PageWriter, 'moodle2aa/canvas_cc/page_writer'
    autoload :DiscussionWriter, 'moodle2aa/canvas_cc/discussion_writer'
    autoload :AssignmentWriter, 'moodle2aa/canvas_cc/assignment_writer'

    autoload :QuestionWriter, 'moodle2aa/canvas_cc/question_writer'
    autoload :CalculatedQuestionWriter, 'moodle2aa/canvas_cc/calculated_question_writer'
    autoload :EssayQuestionWriter, 'moodle2aa/canvas_cc/essay_question_writer'
    autoload :MatchingQuestionWriter, 'moodle2aa/canvas_cc/matching_question_writer'
    autoload :MultipleAnswersQuestionWriter, 'moodle2aa/canvas_cc/multiple_answers_question_writer'
    autoload :MultipleBlanksQuestionWriter, 'moodle2aa/canvas_cc/multiple_blanks_question_writer'
    autoload :MultipleChoiceQuestionWriter, 'moodle2aa/canvas_cc/multiple_choice_question_writer'
    autoload :MultipleDropdownsQuestionWriter, 'moodle2aa/canvas_cc/multiple_dropdowns_question_writer'
    autoload :NumericalQuestionWriter, 'moodle2aa/canvas_cc/numerical_question_writer'
    autoload :ShortAnswerQuestionWriter, 'moodle2aa/canvas_cc/short_answer_question_writer'
    autoload :TextOnlyQuestionWriter, 'moodle2aa/canvas_cc/text_only_question_writer'
    autoload :TrueFalseQuestionWriter, 'moodle2aa/canvas_cc/true_false_question_writer'

    autoload :QuestionBankWriter, 'moodle2aa/canvas_cc/question_bank_writer'
    autoload :QuestionGroupWriter, 'moodle2aa/canvas_cc/question_group_writer'
    autoload :AssessmentWriter, 'moodle2aa/canvas_cc/assessment_writer'
    module Models
      autoload :Course, 'moodle2aa/canvas_cc/models/course'
      autoload :Assignment, 'moodle2aa/canvas_cc/models/assignment'
      autoload :Assessment, 'moodle2aa/canvas_cc/models/assessment'
      autoload :DiscussionTopic, 'moodle2aa/canvas_cc/models/discussion_topic'
      autoload :Question, 'moodle2aa/canvas_cc/models/question'
      autoload :CalculatedQuestion, 'moodle2aa/canvas_cc/models/calculated_question'
      autoload :Answer, 'moodle2aa/canvas_cc/models/answer'
      autoload :QuestionBank, 'moodle2aa/canvas_cc/models/question_bank'
      autoload :QuestionGroup, 'moodle2aa/canvas_cc/models/question_group'
      autoload :WebContent, 'moodle2aa/canvas_cc/models/web_content'
      autoload :WebLink, 'moodle2aa/canvas_cc/models/web_link'
      autoload :Resource, 'moodle2aa/canvas_cc/models/resource'
      autoload :CanvasModule, 'moodle2aa/canvas_cc/models/canvas_module'
      autoload :ModuleItem, 'moodle2aa/canvas_cc/models/module_item'
      autoload :CanvasFile, 'moodle2aa/canvas_cc/models/canvas_file'
      autoload :Page, 'moodle2aa/canvas_cc/models/page'
      autoload :Discussion, 'moodle2aa/canvas_cc/models/discussion'
      autoload :WorkflowState, 'moodle2aa/canvas_cc/models/workflow_state'
    end
  end
  module Moodle2Converter
    autoload :Migrator, 'moodle2aa/moodle2converter/migrator'
    autoload :CourseConverter, 'moodle2aa/moodle2converter/course_converter'
    autoload :QuestionConverters, 'moodle2aa/moodle2converter/question_converters'
    autoload :QuestionBankConverter, 'moodle2aa/moodle2converter/question_bank_converter'
    autoload :SectionConverter, 'moodle2aa/moodle2converter/section_converter'
    autoload :FileConverter, 'moodle2aa/moodle2converter/file_converter'
    autoload :PageConverter, 'moodle2aa/moodle2converter/page_converter'
    autoload :DiscussionConverter, 'moodle2aa/moodle2converter/discussion_converter'
    autoload :AssignmentConverter, 'moodle2aa/moodle2converter/assignment_converter'
    autoload :AssessmentConverter, 'moodle2aa/moodle2converter/assessment_converter'
    autoload :FolderConverter, 'moodle2aa/moodle2converter/folder_converter'
    autoload :BookConverter, 'moodle2aa/moodle2converter/book_converter'
    autoload :ConverterHelper, 'moodle2aa/moodle2converter/converter_helper'
    autoload :HtmlConverter, 'moodle2aa/moodle2converter/html_converter'
    autoload :HomepageConverter, 'moodle2aa/moodle2converter/homepage_converter'
    autoload :GlossaryConverter, 'moodle2aa/moodle2converter/glossary_converter'
    autoload :LabelConverter, 'moodle2aa/moodle2converter/label_converter'
    autoload :WikiConverter, 'moodle2aa/moodle2converter/wiki_converter'
    autoload :GenericActivityConverter, 'moodle2aa/moodle2converter/generic_activity_converter'
  end
end
