require 'byebug'

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::QuestionParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::QuestionParser
    # register_parser_type 'shortanswerwiris'
    # register_parser_type 'multichoicewiris'
    # register_parser_type 'matchwiris'
    # register_parser_type 'multianswerwiris'
    # register_parser_type 'essaywiris'
    # register_parser_type 'truefalsewiris'

    def get_plugin_node(node, type)
      node.at_xpath("plugin_qtype_#{type}_question")
    end

    def get_wiris_node(node, type)
      plugin_node = get_plugin_node(node, type)
      return nil unless plugin_node

      question_xml = plugin_node.at_xpath("question_xml/xml")

      # Question doesn't have anything for us to parse out
      return nil if question_xml.nil? || question_xml.text == "&lt;question/&gt;"

      Nokogiri::XML(question_xml.text)
    end

    def get_code(node, type)

      sheet = get_wiris_node(node, type)
      return [] if sheet.nil?

      # Wrapped in a CDATA tag so we need to parse it out
      cas_session_node = Nokogiri::XML(sheet.xpath("question/wirisCasSession").text)
      algorithms = cas_session_node.xpath("//algorithm").map(&:text)
      algorithms_format = :code

      if algorithms.empty?
        sheets = cas_session_node.xpath("//task")
        algorithms = sheets.map { |s| s.to_xml }
        algorithms_format = :mathml
      end

      [algorithms, algorithms_format]
    end

    def get_answers(node, type)
      plugin_node = get_plugin_node(node, type)
      return [] unless plugin_node

      answer_parser = Parsers::AnswerParser.new
      plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }
    end
  end
end
