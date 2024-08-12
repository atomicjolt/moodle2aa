require "byebug"
module Moodle2AA::Moodle2
  class Parsers::QuestionParsers::Wiris::EssaywirisParser < Moodle2AA::Moodle2::Parsers::QuestionParsers::Wiris::QuestionParser
    register_parser_type 'essaywiris'

    def parse_question(node)
      question = super
      plugin_node = node.at_xpath('plugin_qtype_essaywiris_question')
      question.responseformat = parse_text(plugin_node, 'essay/responseformat')
      question.attachments = parse_text(plugin_node, 'essay/attachments')
      question.attachmentsrequired = parse_text(plugin_node, 'essay/attachmentsrequired')
      question.graderinfo = parse_text(plugin_node, 'essay/graderinfo')
      question.graderinfoformat = parse_text(plugin_node, 'essay/graderinfoformat')
      question.responsetemplate = parse_text(plugin_node, 'essay/responsetemplate')
      question.responsetemplateformat = parse_text(plugin_node, 'essay/responsetemplateformat')
      question.responsefieldlines = parse_text(plugin_node, 'essay/responsefieldlines')
      question
    end
  end
end
