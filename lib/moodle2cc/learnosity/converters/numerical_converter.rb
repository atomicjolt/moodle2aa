module Moodle2CC::Learnosity::Converters
  class NumericalConverter < QuestionConverter
    register_converter_type 'numerical'

    def convert_question(moodle_question)

      if moodle_question.units.count > 0 && moodle_question.unitgradingtype.to_i != 3
        return convert_unit_question(moodle_question)
      end

      import_status = IMPORT_STATUS_COMPLETE
      todo = []

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:is_math] = true
      data[:instantfeedback] = true
      question.type = data[:type] = "formulaV2"
      data[:ui_style] = {type: "no-input-ui"}
      
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      validation[:alt_responses] = []

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      # general feedback gets tacked onto correct/incorrect feedback
      general_feedback = convert_general_feedback moodle_question
      data[:metadata][:correct_feedback] = general_feedback
      data[:metadata][:incorrect_feedback] = general_feedback
      
      correct_feedback = []
      incorrect_feedback = []
      numcorrect = 0
      moodle_question.answers.each do |answer|
        # TODO numerical per-response feedback
        # convert_answer_feedback(answer)
        tolerance = moodle_question.tolerances[answer.id]
        if tolerance.to_f != 0
          value = "#{answer.answer_text} \\pm #{tolerance}"
        else
          value = answer.answer_text
        end
        value = [{method: "equivValue",
                  value: value,
                  options: { decimalPlaces: 10 }
                }]
        response = {score: answer.fraction.to_f, value: value}
        if answer.fraction.to_f == 1 && !validation[:valid_response]
          # first right answer
          validation[:valid_response] = response
        elsif answer.fraction.to_f > 0
          # alternative answers
          validation[:alt_responses] << response
        end
        if answer.fraction.to_f == 1
          numcorrect += 1
        end
        feedback = convert_answer_feedback(answer)
        if html_non_empty? feedback
          data[:is_math] ||= has_math?(feedback)
          if answer.fraction.to_f == 1
            correct_feedback << feedback
          else
            incorrect_feedback << feedback
          end
        end
      end

      # try to handle feedback
      if numcorrect == 1 && correct_feedback.count == 1
        # easy case - add to general correct feedback
        data[:metadata][:correct_feedback] = correct_feedback[0] + "<br/>" + data[:metadata][:correct_feedback]
        correct_feedback.shift
      end

      if correct_feedback.count > 0 || incorrect_feedback.count > 0
        # Can't handle this, so add a conversion note to the instructor stimulus
        data[:instructor_stimulus] = render_conversion_notes(render_feedback_warning(moodle_question.answers))
        import_status = IMPORT_STATUS_PARTIAL
        todo << "Check per response feedback"
      end

      set_penalty_options(question, moodle_question)
      add_instructor_stimulus(question, moodle_question)
      item = create_item(moodle_question: moodle_question, 
                         import_status: import_status,
                         questions: [question],
                         todo: todo)
      return item, [question]
    end
    
    def convert_unit_question(moodle_question)

      import_status = IMPORT_STATUS_PARTIAL #need validation
      todo = []

      question = Moodle2CC::Learnosity::Models::Question.new
      question.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      data = question.data

      data[:stimulus] = convert_question_text moodle_question
      data[:template] = "{{response}}&nbsp; &nbsp; {{response}}&nbsp;(unit)"
      data[:is_math] = true
      data[:instantfeedback] = true
      question.type = data[:type] = "clozeformula"
      data[:ui_style] = {type: "no-input-ui"}
      data[:response_containers] = [{width: "60px"},{width: "20px"}]

      #find all unit names (ft, deg, etc) and make text blocks
      tokens = []
      moodle_question.units.each do |unit|
        tokens += unit[:unit].split(/\W+/)
      end
      data[:text_blocks] = tokens.uniq
      
      validation = data[:validation] = {}
      validation[:scoring_type] = "exactMatch"
      validation[:alt_responses] = []

      data[:metadata] = {}
      rationale = data[:metadata][:distractor_rationale_response_level] = []

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])
      
      correct_feedback = []
      incorrect_feedback = []
      numcorrect = 0
      moodle_question.answers.each do |answer|
        # TODO numerical per-response feedback
        # convert_answer_feedback(answer)
        score = answer.fraction.to_f
        tolerance = moodle_question.tolerances[answer.id]
        moodle_question.units.each do |unit|
          multiplier = unit[:multiplier].to_f
          value = [
            [{method: "equivValue",
                  value: "#{answer.answer_text.to_f*multiplier} \\pm #{tolerance.to_f*multiplier}",
                  options: { decimalPlaces: 10 } }],
            [{method: "equivSymbolic",
             value: unit[:unit],
             options: {} }],
          ]

          response = {score: score, value: value}
          if answer.fraction.to_f == 1 && !validation[:valid_response]
            # first right answer
            validation[:valid_response] = response
          elsif answer.fraction.to_f > 0
            # alternative answers
            validation[:alt_responses] << response
          end
          if answer.fraction.to_f == 1
            numcorrect += 1
          end
          feedback = convert_answer_feedback(answer)
          if html_non_empty? feedback
            data[:is_math] ||= has_math?(feedback)
            if answer.fraction.to_f == 1
              correct_feedback << feedback
            else
              incorrect_feedback << feedback
            end
          end
        end
      end

      # try to handle feedback
      if numcorrect == 1 && correct_feedback.count == 1
        # easy case - add to general correct feedback
        if data[:metadata][:correct_feedback]
          data[:metadata][:correct_feedback] = correct_feedback[0] + "<br/>" + data[:metadata][:correct_feedback]
        else
          data[:metadata][:correct_feedback] = correct_feedback[0]
        end
        correct_feedback.shift
      end

      notes = "<p>This question uses units, however Learnosity support for units is limited.  Students will need to type the units into a separate entry box and there is no partial credit for correct answers with incorrect units. </p>"

      if correct_feedback.count > 0 || incorrect_feedback.count > 0
        # Can't handle this, so add a conversion note to the instructor stimulus
        notes += render_feedback_warning(moodle_question.answers)
        import_status = IMPORT_STATUS_PARTIAL
        todo << "Check per response feedback"
      end
      data[:instructor_stimulus] = render_conversion_notes(notes)

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
