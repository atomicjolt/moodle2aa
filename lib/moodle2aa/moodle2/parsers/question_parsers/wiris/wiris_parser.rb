require 'digest/md5'
require 'httparty'
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

    def get_answers(node, type)
      plugin_node = get_plugin_node(node, type)
      return [] unless plugin_node

      parser = Parsers::AnswerParser.new
      plugin_node.search('answers/answer').map { |n| parser.parse(n) }
    end

    def get_code(node, type, id)
      sheet = get_wiris_node(node, type)
      return [[], :none] if sheet.nil?

      cas_session = sheet.xpath("question/wirisCasSession").text
      sheet_algorithms = get_algorithm_from_session(id, cas_session)
      algorithms_format = :sheet

      [[sheet_algorithms], algorithms_format]
    end

    def get_algorithm_from_session(id, cas_session)
      cas_session_hash = Digest::MD5.hexdigest(cas_session)
      filepath = "out/cached_algorithms/#{id}_#{cas_session_hash}"

      if File.exist?(filepath)
        File.read(filepath)
      else
        puts "Fetching algorithm for #{id}"
        sleep rand(0..2) # Sleep for a random amount of time to (hopefully) avoid rate limiting
        algorithms = convert_sheet_to_algorithm(id, cas_session)

        File.write(filepath, algorithms)
        algorithms
      end
    end

    def convert_sheet_to_algorithm(id, cas_session)
      res = HTTParty.post(
        'https://calcme.com/session2algorithm?httpstatus=true',
        body: URI.encode_www_form({data: cas_session})
      )

      if !res.success?
        raise "Failed to fetch algorithms for #{id}"
      end

      res.body
    end

    def convert_math_ml(string)
      MathML2AsciiMath.m2a(string).
        gsub(/ +/, ''). # Lot of extra spaces in the output
        gsub(/\\/, ' ') # Non-breaking spaces are being substituted with backslashes for some reason
    end
  end
end
