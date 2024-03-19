require 'byebug'
require_relative "./mathml2asciimath"

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::QuestionParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::QuestionParser
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
      return [[], :none] if sheet.nil?

      # Wrapped in a CDATA tag so we need to parse it out
      cas_session_node = Nokogiri::XML(sheet.xpath("question/wirisCasSession").text, &:noblanks)
      code_algorithms = get_algorithms(cas_session_node)
      sheet_algorithms = get_algorithms_from_sheet(cas_session_node)

      algorithms_format = if code_algorithms.length > 0 && sheet_algorithms.length > 0
                            :both
                          elsif code_algorithms.length > 0
                            :code
                          elsif sheet_algorithms.length > 0
                            :sheet
                          else
                            :none
                          end

      algorithms = code_algorithms + sheet_algorithms
      [algorithms, algorithms_format]
    end

    def get_answers(node, type)
      plugin_node = get_plugin_node(node, type)
      return [] unless plugin_node

      answer_parser = Parsers::AnswerParser.new
      plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }
    end

    def get_algorithms(node)
      node.
        xpath("//algorithm").
        map(&:text).
        map { |text| normalize_script_string(text) }
    end

    def get_algorithms_from_sheet(node)
      node.
        xpath("//task//group/command").
        children.
        map(&:to_xml).
        map { |input| convert_math_ml(input) }.
        filter { |input| input != "" }
    end


    def convert_math_ml(string)
      normalize_script_string(
        MathML2AsciiMath.m2a(string).
        gsub(/ +/, ''). # Lot of extra spaces in the output
        gsub(/\\/, ' ') # Non-breaking spaces are being substituted with backslashes for some reason
      )
    end

    def normalize_script_string(string)
      # Normalizes some different syntaxes to a single syntax
      string.
        # gsub(/\(([^\)]+)\)/) { |match| "(" + match[1..-2].gsub(/(;)|(\.\.)/, ',') + ")" }.
        gsub(/\((.+)\.\.(.+)\.\.(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+)\.\.(.+)\)/, "(\\1, \\2)").
        gsub(/\((.+);(.+);(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+);(.+)\)/, "(\\1, \\2)").
        gsub(':=', '=').
        gsub('Pi_', 'PI').
        strip
    end
  end
end
