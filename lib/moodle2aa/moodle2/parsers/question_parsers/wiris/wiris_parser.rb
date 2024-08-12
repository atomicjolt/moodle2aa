require 'digest/md5'
require 'httparty'
require_relative "./mathml2asciimath"

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::QuestionParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::QuestionParser

    def parse_question(node, questiontype = nil)
      question = super

      question.question_text_plain = clean_text(question.question_text)

      question
    end

    def clean_text(text)
      text = fix_html(text)
      xml = Nokogiri::XML(text)
      xml&.root&.text || text
    end

    def fix_html(content)
      # learnosity converts font-weight: bold to a nested <strong>, which messes up
      # table formatting in ece 252
      content = content.gsub(/(<td[^>]*)font-weight:\s*bold/, "\\1font-weight: 700")
      # remove text-align on tables, as it breaks the WYSIWYG editor
      content = content.gsub(/(<table[^>]*)text-align:\s*[a-z]+\s*;?/, "\\1")

      content = content.gsub(/^<p>(.*)<\/p>$/m) do |match|
        # if no other p tags, strip the outer to match learnosity convention
        inner = $1
        if inner.match('<p>')
          match
        else
          inner
        end
      end

      # convert mathml
      lb = "\u00AB"
      rb = "\u00BB"
      quote = "\u00A8"
      singlequote = "\u0060"
      amp = "\u00A7"
      re = /  <math[^>]*>.+?<\/math>
            | #{lb}math[^#{rb}]*#{rb}.+?#{lb}\/math#{rb}
           /xm
      content = content.gsub(re) do |match|
        match.to_s.tr("#{lb}#{rb}#{quote}#{singlequote}#{amp}", "<>\"'&")
      end

      # convert latex
      latexre = /<tex(?:\s+alt=["\'](?<e>.*?)["\'])?>(.+?)<\/tex>|\$\$(?<e>.+?)\$\$|\[tex\](?<e>.+?)\[\/tex\]/m
      content = content.gsub(latexre) do | match|
        latex=$~[:e]
        latex = latex.tr("\n"," ")
        latex = latex.gsub(/\\\((.*?)\\\)/, "\\text{\\1}")

        '\\('+latex+'\\)'
      end

      # fix mathml empty elements so learnosity doesn't strip them
      content = content.gsub(/<mrow><\/mrow>/, "<mrow> <\/mrow>")
      content = content.gsub("<mspace linebreak=\"newline\"/>", "\n")
      content = content.gsub(/<br.*?>/, "\n")
    end

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
