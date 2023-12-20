module Moodle2CC::Moodle2
  class Parsers::QuestionParsers::EssayParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('essay')

    def parse_question(node)
      question = super
      q_node = node.at_xpath('plugin_qtype_essay_question')
      question.responseformat = parse_text(q_node, 'essay/responseformat')
      question.attachments = parse_text(q_node, 'essay/attachments')
      question.attachmentsrequired = parse_text(q_node, 'essay/attachmentsrequired')
      question.graderinfo = parse_text(q_node, 'essay/graderinfo')
      question.graderinfoformat = parse_text(q_node, 'essay/graderinfoformat')
      question.responsetemplate = parse_text(q_node, 'essay/responsetemplate')
      question.responsetemplateformat = parse_text(q_node, 'essay/responsetemplateformat')
      question.responsefieldlines = parse_text(q_node, 'essay/responsefieldlines')
      question
    end

  end
end
