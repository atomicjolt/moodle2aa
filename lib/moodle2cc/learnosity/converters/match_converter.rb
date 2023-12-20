module Moodle2CC::Learnosity::Converters
  class MatchConverter < QuestionConverter
    register_converter_type 'match'

    def convert_question(moodle_question)

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:is_math] = has_math?(data[:stimulus])
      data[:instantfeedback] = true
      question.type = data[:type] = "association"
      
      data[:duplicate_responses] = true  # moodle always allows this

      validation = data[:validation] = {}

      data[:metadata] = {}

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])
      data[:shuffle_options] = moodle_question.shuffle

#      {
#    "stimulus": "<p>[This is the stem.]</p>",
#    "stimulus_list": ["[Stem 1]", "[Stem 2]", "[Stem 3]"],
#    "type": "association",
#    "validation": {
#        "scoring_type": "exactMatch",
#        "valid_response": {
#            "score": 1,
#            "value": ["[Choice A]", "[Choice B]", "[Choice C]"]
#        }
#    },
#    "shuffle_options": true,
#    "possible_responses": ["[Choice A]", "[Choice B]", "[Choice C]"]
#      }

      validation[:scoring_type] = "partialMatchV2"
      #validation[:penalty] = 1
      validation[:rounding] = "none"
      validation[:valid_response] = { score: 1 }

      possible_responses = data[:possible_responses] = []
      stimulus_list = data[:stimulus_list] = []
      valid_response = validation[:valid_response][:value] = []

      moodle_question.matches.each do |match|
        stimulus = convert_match_text(match, moodle_question)
        response = match[:answer_text]
        if html_non_empty?(stimulus)
          # a stimulus/response pair
          stimulus_list << stimulus
          valid_response << response
          possible_responses << response
        elsif response != ''
          # a distractor
          possible_responses << match[:answer_text]
        end
      end
      possible_responses.uniq!
      data[:is_math] ||= has_math?(possible_responses)
      data[:is_math] ||= has_math?(stimulus_list)

      # deterministic shuffle
      possible_responses.shuffle!(random: Random.new(moodle_question.id.to_i*4234))

      question.scale_score(moodle_question.default_mark)
      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question, 
                         import_status: IMPORT_STATUS_COMPLETE,
                         questions: [question])
      return item, [question]
    end

    def convert_match_text(match, moodle_question)
      material = match[:question_text] || ''
      material = RDiscount.new(material).to_html if match[:question_text_format].to_i == 4 # markdown
      material = convert_latex material
      @html_converter.convert(material, 'qtype_match', 'subquestion', match[:id])
    end
  end
end
