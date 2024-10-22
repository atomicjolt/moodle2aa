require "byebug"

module Moodle2AA::Moodle2::Models::Quizzes::Wiris
  class WirisQuestion < Moodle2AA::Moodle2::Models::Quizzes::Question
    attr_accessor :algorithms, :algorithms_format, :has_compound_answer, :initial_content, :tolerance, :relative_tolerance, :tolerance_digits, :precision

    SUBSTITUTION_VARIABLE_REGEX = /#([\D][\w\d]*)\b/

    SCRIPT_VARIABLE_REGEX = /\s*([\w\d]+)? =/

    def learnosity_question_text
      learnosity_question_text = question_text.gsub(SUBSTITUTION_VARIABLE_REGEX, '{{var:\1}}')
    end

    # Variables can be in: question_text, answers[*].answer_text,
    def substitution_variables
      return @substitution_variables if @substitution_variables

      @substitution_variables = Set.new

      @substitution_variables.merge(question_text_plain.scan(SUBSTITUTION_VARIABLE_REGEX).flatten)

      answers.map do |answer|
        next unless answer.answer_text_plain
        @substitution_variables.merge(answer.answer_text_plain.scan(SUBSTITUTION_VARIABLE_REGEX).flatten)
      end

      @substitution_variables.filter! { |v| script_variables.include?(v) }

      @substitution_variables
    end

    def script_variables
      return @script_variables if @script_variables

      @script_variables = Set.new

      (algorithms || []).each do |algorithm|
        @script_variables.merge(algorithm.scan(SCRIPT_VARIABLE_REGEX).flatten)
      end

      @script_variables.filter! { |v| v != "" }

      @script_variables
    end
  end
end
