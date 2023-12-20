module Moodle2CC::Learnosity::Converters
  class MultiChoiceConverter < QuestionConverter
    register_converter_type 'multichoice'

    def convert_question(moodle_question)

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:is_math] = has_math?(data[:stimulus])
      data[:instantfeedback] = true
      question.type = data[:type] = "mcq"
      data[:multiple_responses] = !moodle_question.single
      data[:ui_style] = {type: "horizontal"}

      data[:shuffle_options] = moodle_question.shuffle
      
      options = data[:options] = []
      validation = data[:validation] = {}
      validation[:alt_responses] = []

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

      value = 0;
      moodle_question.answers.each do |answer|
        options << {label: convert_answer_text(answer),
                    value: value.to_s}
        rationale << convert_answer_feedback(answer)
        if moodle_question.single
          # single select
          validation[:scoring_type] = "exactMatch"
          response = {score: answer.fraction.to_f, value: [value.to_s]}
          if answer.fraction.to_f == 1 && !validation[:valid_response]
            validation[:valid_response] = response
          elsif answer.fraction.to_f > 0
            validation[:alt_responses] << response
          end
        else
          # multiple select
          # per-item custom response weighting is dropped.  There's nothing we
          # can really do about that.  Instead we go with uniform positive scores
          # for correct answers and negative penalty for incorrect answers.
          validation[:scoring_type] = "partialMatchV2"
          validation[:penalty] = 1
          validation[:rounding] = "none"
          validation[:valid_response] ||= {score: 1, value: []}
          if answer.fraction.to_f > 0
            validation[:valid_response][:value] << value.to_s
          end
        end
        value += 1
      end
      options.each { |option| data[:is_math] ||= has_math?(option[:label]) }
      rationale.each { |feedback| data[:is_math] ||= has_math?(feedback) }
      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question, 
                         import_status: IMPORT_STATUS_COMPLETE,
                         questions: [question])
      return item, [question]
    end
  end
end
