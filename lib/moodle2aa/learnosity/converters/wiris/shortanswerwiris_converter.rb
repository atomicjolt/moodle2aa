require 'byebug'
require_relative './wiris_algorithm_converter'

module Moodle2AA::Learnosity::Converters::Wiris
  class ShortAnswerWirisConverter < Moodle2AA::Learnosity::Converters::QuestionConverter
    register_converter_type 'shortanswerwiris'

    SUBSTITUTION_VARIABLE_REGEX = /#([\w\d]+)\b/

    def convert_question(moodle_question)
      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text(moodle_question).gsub(SUBSTITUTION_VARIABLE_REGEX, '{{var:\1}}')
      data[:is_math] = has_math?(data[:stimulus])
      data[:case_sensitive] = moodle_question.casesensitive
      question.type = data[:type] = "clozeformulaV2"

      validation = data[:validation] = {}
      validation[:alt_responses] = []

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

      import_status = IMPORT_STATUS_COMPLETE
      todo = []

      validation[:scoring_type] = "exactMatch"

      # TODO: We can't just scan for substiution variables, we also need to scan for
      # literal values that are not substitution variables. IE:
      # r(s) = #tau <= Substitution variable
      # r(s) = 1.0 <= Literal value
      # I figure we can scan for equal signs and then take whats to the right of the equal sign as the value

      moodle_question.answers.each do |answer|
        response = {score: answer.fraction.to_f}

        response[:value] = answer.answer_text_plain.scan(SUBSTITUTION_VARIABLE_REGEX).map do |match|
          {
            method: "equivLiteral",
            value: "{{var:#{match.first}}}"
          }
        end

        if answer.fraction.to_f == 1 && !validation[:valid_response]
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          validation[:alt_responses] << response
        end
      end

      # TODO: the template doesn't have new lines between responses
      # Like they typically do in moodle
      data[:template] = moodle_question.answers.first.answer_text_plain.gsub!(SUBSTITUTION_VARIABLE_REGEX, '{{response}}')

      # moodle_question.answers.each do |answer|
      #   value = answer.answer_text.strip

      #   response = {score: answer.fraction.to_f}
      #   # deal with wildcards, when we can

      #   # leading/trailing *'s become substring matches
      #   if value[0] == '*'
      #     response['matching_rule'] = 'contains'
      #     value[0] = ''
      #   end
      #   if value[-1] == '*' && value[-2] != '\\'
      #     response['matching_rule'] = 'contains'
      #     value[-1] = ''
      #   end

      #   if value.match(/[^\\]\*/)
      #     # other wildcards.  Can't really handle these
      #     # In most cases these are formulas and better converted to a math qtype.  For answers like red*blue an option would be
      #     # to have two answer checkers.  In either case we'll leave these for manual conversion.
      #     import_status = IMPORT_STATUS_MANUAL
      #     todo << "Check short answer wildcards"
      #     data[:instructor_stimulus] = render_conversion_notes("Learnosity short text questions don't support '*' wildcards.  Please review the question answers.")
      #   end
      #   # replace escaped * with literal *.  These are not wildcards in moodle.
      #   value.gsub!(/[\\]\*/,'*')
      #   response['value'] = value

      #   rationale << convert_answer_feedback(answer)

      #   if answer.fraction.to_f == 1 && !validation[:valid_response]
      #     validation[:valid_response] = response
      #   elsif answer.fraction.to_f > 0
      #     validation[:alt_responses] << response
      #   end
      # end
      rationale.each { |feedback| data[:is_math] ||= has_math?(feedback) }
      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)

      js_script, is_valid = WirisAlgorithmConverter.convert_algorithms(moodle_question)

      if !is_valid
        import_status = IMPORT_STATUS_PARTIAL
        todo << "Check Data Table Script"
      end

      item = create_item(moodle_question: moodle_question,
                         import_status: import_status,
                         questions: [question],
                         todo: todo,
                         data_table_script: js_script)
      return item, [question]
    end
  end
end
