module Moodle2AA::Moodle2::Models::Quizzes
  class EssayQuestion < Question
    register_question_type 'essay'
    register_question_type 'essaywiris'

    attr_accessor :responseformat, :attachments, :attachmentsrequired
    attr_accessor :graderinfo, :graderinfoformat, :responsetemplate
    attr_accessor :responsetemplateformat, :responsefieldlines
  end
end
