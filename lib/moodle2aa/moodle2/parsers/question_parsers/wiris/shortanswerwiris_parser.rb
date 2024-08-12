require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::ShortnswerwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super

      plugin_node = get_plugin_node(node, 'shortanswerwiris')
      question_xml = get_wiris_node(node, 'shortanswerwiris')

      question.answers = get_answers(node, 'shortanswerwiris')
      question.casesensitive = parse_boolean(plugin_node, 'shortanswer/usecase')
      question.algorithms, question.algorithms_format = get_code(node, 'shortanswerwiris', question.id)

      if question_xml
        question.tolerance = parse_text(question_xml, 'options/option[@name="tolerance"]').to_f
        question.relative_tolerance = parse_boolean(question_xml, 'options/option[@name="relative_tolerance"]')
        question.tolerance_digits = parse_boolean(question_xml, 'options/option[@name="tolerance_digits"]')

        # In Compound answers, there's only one answer object, but it has multiple parts, we need to split it apart
        question.has_compound_answer = parse_boolean(question_xml, "//localData/data[@name='inputCompound']")
        question.initial_content = question_xml.at_xpath("//initialContent")&.children&.first&.text
        question.initial_content = nil if question.initial_content == ""
      else
        question.has_compound_answer = false
        question.initial_content = nil
      end

      question.answers.each do |answer|
        answer.answer_text_plain = clean_text(answer.answer_text)
      end

      question
    end
  end
end
