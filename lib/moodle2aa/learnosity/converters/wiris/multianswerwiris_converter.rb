require "debug"

module Moodle2AA::Learnosity::Converters::Wiris
  class MultiAnswerWirisConverter < Moodle2AA::Learnosity::Converters::QuestionConverter
    include WirisHelper

    register_converter_type 'multianswerwiris'

    def convert_question(moodle_question)
      questions = [] # may have to break into multiple questions
      notes = []
      todo = []
      import_status = IMPORT_STATUS_COMPLETE # best case

      embedded_questions = moodle_question.embedded_questions.clone
      total_parts = embedded_questions.count

      question_text = replace_wiris_variables(convert_question_text(moodle_question))

      while true
        if embedded_questions.count == 0
          # malformed question.  Gaps courses don't have any of these.
          abort "Multi answer with no subquestions??"
        end

        # create a new cloze question
        question = Moodle2AA::Learnosity::Models::Question.new
        questions << question
        question.reference = generate_unique_identifier_for(moodle_question.id, "_question_#{questions.count}")

        data = question.data
        data[:instantfeedback] = true
        data[:template] = ''

        validation = data[:validation] = {}
        validation[:scoring_type] = "partialMatchV2"  # One point per item.  Moodle tends to do it this way,
                                                    # and this is compatible with breaking up inhomogenious
                                                    # cloze questions into multiple questions.
        validation[:rounding] = "none"
        validation[:valid_response] = {score: 0, value: []}

        currenttype = nil
        while subquestion = embedded_questions[0]
          currenttype ||= embedded_questions[0].class
          if !(currenttype == embedded_questions[0].class)
            # mixed subquestion types.
            todo << "Check cloze conversion"
            notes << "This cloze question contains a mix of different types of answer elements and has automatically been split into multiple questions."
            import_status = IMPORT_STATUS_MANUAL
            break # loop to start a new question
          end
          moodle_subquestion = embedded_questions.shift
          # each part is equal weight
          validation[:valid_response][:score] += 1.0/total_parts

          before, after = question_text.split(/{#\d+}/, 2)
          binding.break if !after
          abort "missing cloze marker??" if !after

          data[:template] += before+"{{response}}"
          question_text = after

          case
          when currenttype == Moodle2AA::Moodle2::Models::Quizzes::Wiris::MultichoiceWirisQuestion
            question.type = data[:type] = "clozedropdown"
            data[:case_sensitive] = true
            data[:ui_style] = {type: "horizontal"}
            data[:shuffle_options] = moodle_subquestion.shuffle
            data[:response_container] = { pointer: "left" }

            data[:possible_responses] ||= []
            data[:possible_responses] << moodle_subquestion.answers.map {|a| replace_wiris_variables(convert_answer_text(a))}
            correct = moodle_subquestion.answers.select {|a| a.fraction.to_f == 1}
            validation[:valid_response][:value] << replace_wiris_variables(convert_answer_text(correct[0]))

            all = moodle_subquestion.answers.select {|a| a.fraction.to_f > 1}
            if all.count > 1
              # We don't convert multiple answers automatically.  It may be possible
              # manually.
              todo << "Check cloze conversion"
              notes << "This cloze question contained multiple correct answers in Moodle, some of which were not converted automatically."
              import_status = IMPORT_STATUS_MANUAL
            end
          when currenttype == Moodle2AA::Moodle2::Models::Quizzes::Wiris::ShortAnswerWirisQuestion
            question.type = data[:type] = "clozetext"
            data[:case_sensitive] = moodle_subquestion.casesensitive

            correct = moodle_subquestion.answers.select {|a| a.fraction.to_f == 1}
            answer_text = replace_wiris_variables(convert_answer_text(correct[0]))
            validation[:valid_response][:value] << answer_text
            data[:max_length] = [15, answer_text.length+1].min

            all = moodle_subquestion.answers.select {|a| a.fraction.to_f > 1}
            if all.count > 1
              # We don't convert multiple answers automatically.  It may be possible
              # manually.
              todo << "Check cloze conversion"
              notes << "This cloze question contained multiple correct answers in Moodle, some of which were not converted automatically."
              import_status = IMPORT_STATUS_MANUAL
            end
          when currenttype == Moodle2AA::Moodle2::Models::Quizzes::NumericalQuestion
            question.type = data[:type] = "clozeformula"
            data[:ui_style] = {type: "no-input-ui"}
            data[:response_container] = {template: ""}

            correct = moodle_subquestion.answers.select {|a| a.fraction.to_f == 1}
            tolerance = moodle_subquestion.tolerances[correct[0].id]
            value = [{method: "equivValue",
                      value: "#{correct[0].answer_text} \\pm #{tolerance}",
                      options: { decimalPlaces: 10 }
                    }]
            validation[:valid_response][:value] << value

            all = moodle_subquestion.answers.select {|a| a.fraction.to_f > 1}
            if all.count > 1
              # We don't convert multiple answers automatically.  It may be possible
              # manually.
              todo << "Check cloze conversion"
              notes << "This cloze question contained multiple correct answers in Moodle, some of which were not converted automatically."
              import_status = IMPORT_STATUS_MANUAL
            end
          else
            abort "Unknown subquestion type"
          end
        end

        notes = notes.uniq
        data[:instructor_stimulus] = render_conversion_notes(notes)

        if embedded_questions.count == 0
          # no parts remaining
          data[:template] += question_text  # add whatever text is left
          break
        end

        # otherwise must be a mixture of different answer elements, so loop to
        # create another question.

      end

      data[:is_math] = false
      questions.each do |question|
        data[:is_math] ||= has_math?(question.data[:template])
      end

      data[:metadata] = {}

      data[:metadata].merge!(convert_feedback( moodle_question ))
      data[:is_math] ||= has_math?(data[:metadata])

              questions.each {|question| question.scale_score(moodle_question.default_mark)}
      questions.each {|question| set_penalty_options(question, moodle_question) }
      questions.each {|question| add_instructor_stimulus(question, moodle_question) }


      script, is_valid = generate_datatable_script(moodle_question)

      if !is_valid
        import_status = IMPORT_STATUS_PARTIAL
        todo << "Check Data Table Script"
      end

      item = create_item(moodle_question: moodle_question,
                         import_status: import_status,
                         questions: questions,
                         todo: todo,
                         data_table_script: script)
      return item, questions
    end
  end
end
