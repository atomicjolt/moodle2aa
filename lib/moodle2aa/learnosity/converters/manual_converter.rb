module Moodle2AA::Learnosity::Converters
  class ManualConverter < QuestionConverter
    register_converter_type 'ddimageortext'
    register_converter_type 'ddmarker'
    register_converter_type 'ddwtos'
    register_converter_type 'drawing'
    register_converter_type 'order'
    register_converter_type 'poodllrecording'
    register_converter_type 'stack'
    register_converter_type 'varnumeric'
    register_converter_type 'varnumericset'

    def convert_question(moodle_question)
      # create a stub marked for manual conversion
      convert_question_stub(moodle_question, true)
    end
  end
end
