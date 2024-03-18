require 'byebug'
require_relative "./mathml2asciimath"

module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::ShortnswerwirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'shortanswerwiris'

    def parse_question(node)
      question = super

      plugin_node = get_plugin_node(node, 'shortanswerwiris')

      answer_parser = Parsers::AnswerParser.new
      question.answers += plugin_node.search('answers/answer').map { |n| answer_parser.parse(n) }
      question.casesensitive = parse_boolean(plugin_node, 'shortanswer/usecase')


      question.algorithms, question.algorithms_format = get_code(node, 'shortanswerwiris')

      byebug if question.algorithms == nil

      puts '-----------------------------------'
      puts "Name: #{question.name}"
      puts "Format: #{question.algorithms_format}"
      puts '-----------------------------------'
      puts question.algorithms.join("\n")

      if question.algorithms_format != :none
        question.answers.each do |answer|
          next unless answer.answer_text.start_with?('<math')
          answer.answer_text_plain = convert_math_ml(answer.answer_text)
        end
      end

      question
    end
  end
end
