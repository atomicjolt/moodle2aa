module Moodle2CC::Learnosity::Converters
  class GapselectConverter < QuestionConverter
    register_converter_type 'gapselect'

    def convert_question(moodle_question)

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:template] = convert_question_text moodle_question
      data[:is_math] = has_math?(data[:template])
      data[:instantfeedback] = true
      question.type = data[:type] = "clozedropdown"
      data[:case_sensitive] = true
      data[:ui_style] = {type: "horizontal"}

      data[:shuffle_options] = moodle_question.shuffleanswers
      data[:response_container] = { pointer: "left" }
      
      data[:possible_responses] = []
      validation = data[:validation] = {}
      validation[:scoring_type] = "partialMatchV2"
      validation[:rounding] = "none"
      validation[:valid_response] = {score: 1, value: []}

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

      value = 0;
      groups = {}
      responses = {}
      
      index = 1
      moodle_question.answers.each do |answer|
        groupnum = answer.feedback.to_i
        answertext = convert_answer_text(answer)
        groups[groupnum] ||= []
        groups[groupnum] << answertext
        responses[index] = { value: answertext, options: groups[groupnum] }
        index += 1
      end

      data[:template].gsub!(/\[\[([0-9]+)\]\]/) do |match|
        index = $1.to_i
        response = responses[index]
        if response
          data[:possible_responses] << response[:options]
          data[:validation][:valid_response][:value] << response[:value]
          '{{response}}'
        else
          # no group, just leave it
          match
        end
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
