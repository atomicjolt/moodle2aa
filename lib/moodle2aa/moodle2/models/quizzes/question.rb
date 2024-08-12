module Moodle2AA::Moodle2::Models::Quizzes
  class Question

    @@subclasses = {}

    STANDARD_TYPES = ['description', 'essay', 'random', 'shortanswer']

    def self.create(type)
      if c = @@subclasses[type]
        q = c.new
        q.type = type
        q
      elsif STANDARD_TYPES.include?(type)
        q = self.new
        q.type = type
        q
      elsif Moodle2AA::MigrationReport.convert_unknown_qtypes?
        c = @@subclasses['unknowntype']
        q = c.new
        q.type = type
        q
      else
        raise "Unknown question type: #{type}"
      end
    end

    def self.register_question_type(name)
      @@subclasses[name] = self
    end

    attr_accessor :id, :parent, :name, :question_text, :question_text_format, :general_feedback, :default_mark, :max_mark,
                  :penalty, :qtype, :length, :stamp, :version, :hidden, :answers, :type
    attr_accessor :category_name  # for learnosity random conversion
    attr_accessor :category_id  # for learnosity synchronized calc conversion
    attr_accessor :hints, :penalty
    attr_accessor :question_text_plain

    def initialize
      @answers = []
      @hints = []
    end
  end
end
