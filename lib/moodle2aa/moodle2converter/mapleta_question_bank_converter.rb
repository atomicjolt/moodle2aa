module Moodle2AA::Moodle2Converter
  class QuestionBankConverter
    include ConverterHelper

    def convert(moodle_category)
      canvas_bank = Moodle2AA::CanvasCC::Models::QuestionBank.new

      canvas_page = Moodle2AA::CanvasCC::Models::Page.new
      canvas_page.identifier = generate_unique_identifier_for(moodle_category.id, '_mapleta')
      canvas_page.page_name = "#{moodle_category.name} MapleTA LaTeX Source";
      canvas_page.workflow_state = workflow_state(moodle_page.visible)
      canvas_page.editing_roles = 'teachers'

      question_converter = Moodle2AA::Moodle2Converter::QuestionConverters::QuestionConverter.new
      src = ''
      moodle_category.questions.each do |moodle_question|
        src << question_converter.convert_to_mapleta(moodle_question)
      end

      canvas_page.body = src.join("\n")
      canvas_page
    end
  end
end