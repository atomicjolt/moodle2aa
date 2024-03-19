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

      moodle_question.answers.each do |answer|
        response = {score: answer.fraction.to_f}

        response[:value] = answer.answer_text_plain.scan(/(.+)=(.+)/).map do |match|
          # If it has substitution variables, we need to convert them to the
          # Learnosity format & we assume that we should compare by numerical
          # equivalence. Otherwise, it's a literal value comparison.
          if match[1].match(SUBSTITUTION_VARIABLE_REGEX)
            [{
              method: "equivValue",
              result: match[1].gsub(SUBSTITUTION_VARIABLE_REGEX, '{{var:\1}}'),
              options: {
                # TODO: we should be able to infer this from the question
                # however, it might be more effort than it's woth to get
                # it right, so we'll just assume 2 decimal places for now
                decimalPlaces: 2,
              }
            }]
          else
            [{
                method: "equivLiteral",
                value: match[1]
            }]
          end
        end

        rationale << convert_answer_feedback(answer)

        if answer.fraction.to_f == 1 && !validation[:valid_response]
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          validation[:alt_responses] << response
        end
      end

      # TODO: don't use the plain text as the template, we should use
      # the provided MathML (with variables swapped out)
      data[:template] = moodle_question.answers.first.answer_text_plain.
        gsub(/=(.+)/, '={{response}}').
        gsub(/\n/, '<br>')

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
