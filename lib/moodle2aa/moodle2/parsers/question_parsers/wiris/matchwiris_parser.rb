require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::MatchwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'matchwiris'

    def parse_question(node)
      question = super(node, 'matchwiris')

      plugin_node = node.at_xpath("plugin_qtype_#{question.qtype}_question")

      plugin_node.search('matches/match').each do |m_node|
        question.matches << {
          :id => m_node.attributes['id'].value,
          :question_text => parse_text(m_node, 'questiontext'),
          :question_text_format => parse_text(m_node, 'questiontextformat'),
          :answer_text => parse_text(m_node, 'answertext')
        }
      end

      question.shuffle = parse_boolean(plugin_node.search('matchoptions'), 'shuffleanswers')
      question.correctfeedback = parse_text(plugin_node.search('matchoptions'), 'correctfeedback')
      question.partiallycorrectfeedback = parse_text(plugin_node.search('matchoptions'), 'partiallycorrectfeedback')
      question.incorrectfeedback = parse_text(plugin_node.search('matchoptions'), 'incorrectfeedback')

      question
    end
  end
end
