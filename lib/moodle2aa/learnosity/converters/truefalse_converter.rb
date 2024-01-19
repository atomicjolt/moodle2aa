module Moodle2AA::Learnosity::Converters
  class TrueFalseConverter < QuestionConverter
    register_converter_type 'truefalse'

    def convert_question(moodle_question)

      question = Moodle2AA::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:is_math] = has_math?(data[:stimulus])
      data[:instantfeedback] = true
      question.type = data[:type] = "mcq"
      data[:ui_style] = {type: "horizontal"}
      
      options = data[:options] = []
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      
      data[:metadata] = {}
      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])
      
      value = 0;
      moodle_question.answers.each do |answer|
        options << {label: convert_answer_text(answer),
                    value: value.to_s}
        # TODO MCQ per-response feedback
        #convert_answer_feedback(answer)
        response = {score: answer.fraction.to_f, value: [value.to_s]}
        if answer.fraction.to_f == 1 && !validation[:valid_response]
          validation[:valid_response] = response
        end
        value += 1
      end

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
