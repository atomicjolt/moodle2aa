require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::QuestionParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::QuestionParser
    register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super

      parse_wiris(node, question)

      question
    end

    def parse_wiris(node, question)
      plugin_node = node.at_xpath("plugin_qtype_#{question.type}_question")
      return unless plugin_node

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }

      # Handle the Variables
      question_xml = plugin_node.at_xpath("question_xml/xml")

      # Question doesn't have anything for us to parse out
      return if question_xml.nil? || question_xml.text == "&lt;question/&gt;"

      sheet = Nokogiri::XML(question_xml.text)
      # Wrapped in a CDATA tag so we need to parse it out
      cas_session_node = Nokogiri::XML(sheet.xpath("question/wirisCasSession").text)
      algorithms = cas_session_node.xpath("//algorithm").map(&:text)

      if algorithms.empty?
        sheets = cas_session_node.xpath("//task")
        # TODO: Generate Algorithm from the sheets
        algorithms = []
      end

      byebug if ["Q1", "The Red Riding Hood"].include?(question.name)
      question.algorithms = algorithms
    end
  end
end
