module Moodle2AA::Learnosity::Converters
  class RandomConverter < QuestionConverter
    register_converter_type 'random'

    def convert_question(moodle_question)
      return nil,nil

      feature = Moodle2AA::Learnosity::Models::Feature.new
      feature.type = feature.data[:type] = 'sharedpassage'
      feature.reference = generate_unique_identifier_for(moodle_question.id, '_question')

      content = "<b>*** Random question from category \"#{moodle_question.category_name}\" *** </b>"

      feature.data[:content] = content
      item = create_item(moodle_question: moodle_question, 
                         title: moodle_question.name,
                         import_status: IMPORT_STATUS_MANUAL,
                         features: [feature])
      return item, [feature]
    end
  end
end
