module Moodle2CC::Learnosity::Converters
  class ShortanswerConverter < QuestionConverter
    register_converter_type 'shortanswer'

    def convert_question(moodle_question)

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:is_math] = has_math?(data[:stimulus])
      data[:case_sensitive] = moodle_question.casesensitive
      question.type = data[:type] = "shorttext"

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
        value = answer.answer_text.strip

        response = {score: answer.fraction.to_f}
        # deal with wildcards, when we can
        
        # leading/trailing *'s become substring matches
        if value[0] == '*'
          response['matching_rule'] = 'contains'
          value[0] = ''
        end
        if value[-1] == '*' && value[-2] != '\\'
          response['matching_rule'] = 'contains'
          value[-1] = ''
        end

        if value.match(/[^\\]\*/)
          # other wildcards.  Can't really handle these
          # In most cases these are formulas and better converted to a math qtype.  For answers like red*blue an option would be
          # to have two answer checkers.  In either case we'll leave these for manual conversion.
          import_status = IMPORT_STATUS_MANUAL
          todo << "Check short answer wildcards"
          data[:instructor_stimulus] = render_conversion_notes("Learnosity short text questions don't support '*' wildcards.  Please review the question answers.")
        end
        # replace escaped * with literal *.  These are not wildcards in moodle.
        value.gsub!(/[\\]\*/,'*')
        response['value'] = value

        rationale << convert_answer_feedback(answer)

        if answer.fraction.to_f == 1 && !validation[:valid_response]
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          validation[:alt_responses] << response
        end
      end
      rationale.each { |feedback| data[:is_math] ||= has_math?(feedback) }
      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question, 
                         import_status: import_status,
                         questions: [question],
                         todo: todo)
      return item, [question]
    end
  end
end
