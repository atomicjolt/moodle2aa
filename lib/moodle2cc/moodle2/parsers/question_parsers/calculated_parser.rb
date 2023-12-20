module Moodle2CC::Moodle2
  class Parsers::QuestionParsers::CalculatedParser < Parsers::QuestionParsers::QuestionParser
    include Parsers::ParserHelper
    register_parser_type('calculated')
    register_parser_type('calculatedmulti')
    register_parser_type('calculatedsimple')
    register_parser_type('calculatedformat')

    def parse_question(node)
      question = super(node, 'calculated')

      if question.qtype == 'calculatedformat'
        return parse_calculated_format_question(node, question)
      end

      q_node = node.at_xpath("plugin_qtype_#{question.qtype}_question")

      answer_parser = Parsers::AnswerParser.new
      question.answers += q_node.search('answers/answer').map { |n| answer_parser.parse(n) }

      # Keep the extra answers around for MapleTA.  The code should have stripped the extra
      # answers in the converter, not the model.  Oh well.
      question.all_answers = question.answers.clone
      question.synchronize = parse_boolean(q_node.search('calculated_options/calculated_option'), 'synchronize')
      question.single = parse_boolean(q_node.search('calculated_options/calculated_option'), 'single')
      question.shuffleanswers = parse_boolean(q_node.search('calculated_options/calculated_option'), 'shuffleanswers')
      q_node.search('calculated_records/calculated_record').each do |cr_node|
        answer_id = parse_text(cr_node, 'answer')
        tolerance = parse_text(cr_node, 'tolerance')
        tolerancetype = parse_text(cr_node, 'tolerancetype')
        correct_answer_format = parse_text(cr_node, 'correctanswerformat')
        correct_answer_length = parse_text(cr_node, 'correctanswerlength')
        question.all_options[answer_id.to_i] = {
               :tolerance => tolerance,
               :tolerancetype => tolerancetype,
               :correct_answer_format => correct_answer_format,
               :correct_answer_length => correct_answer_length,
        }
      end

      if question.answers.count > 1 && question.qtype == 'calculatedmulti'
        # turn multiple choice calculated questions into standard formula questions,
        # by ignoring the incorrect formulas
        if correct_formula = question.answers.detect{|a| a.fraction == 1}
          question.answers = [correct_formula]
        end
      end

      q_node.search('dataset_definitions/dataset_definition').each do |ds_node|
        var_name = parse_text(ds_node, 'name')
        question.dataset_definitions << {
            :name => var_name,
            :options => parse_text(ds_node, 'options'),
            :id => ds_node.attributes['id'].value,
            :category => parse_text(ds_node, 'category'),
            :itemcount => parse_text(ds_node, 'itemcount'),
        }
        ds_node.search('dataset_items/dataset_item').each do |ds_item_node|
          ident = parse_text(ds_item_node, 'number')
          var_set = question.var_sets.detect{|vs| vs[:ident] == ident}
          unless var_set
            var_set = {:ident => ident, :vars => {}}
            question.var_sets << var_set
          end
          var_set[:vars][var_name] = parse_text(ds_item_node, 'value')
        end
      end

      q_node.search('calculated_records/calculated_record').each do |cr_node|
        next unless parse_text(cr_node, 'answer') == question.answers.first.id.to_s

        question.correct_answer_format = parse_text(cr_node, 'correctanswerformat')
        question.correct_answer_length = parse_text(cr_node, 'correctanswerlength')
        question.tolerance = parse_text(cr_node, 'tolerance')
      end

      question
    end

  def parse_calculated_format_question(node, question)

    q_node = node.at_xpath("plugin_qtype_#{question.qtype}_question")

    answer_parser = Parsers::AnswerParser.new
    question.answers += q_node.search('answers/answer').map { |n| answer_parser.parse(n) }

    # Keep the extra answers around for MapleTA.  The code should have stripped the extra
    # answers in the converter, not the model.  Oh well.
    question.all_answers = question.answers.clone
    question.synchronize = parse_boolean(q_node.search('calculatedformat_options/calculatedformat_option'), 'synchronize')
    q_node.search('calculatedformat_records/calculatedformat_record').each do |cr_node|
      answer_id = parse_text(cr_node, 'answerid')
      tolerance = parse_text(cr_node, 'tolerance')
      tolerancetype = parse_text(cr_node, 'tolerancetype')
      correct_answer_format = parse_text(cr_node, 'correctanswerformat')
      correct_answer_length = parse_text(cr_node, 'correctanswerlength')

      question.all_options[answer_id.to_i] = {
             :tolerance => tolerance,
             :tolerancetype => tolerancetype,
             :correct_answer_format => correct_answer_format,
             :correct_answer_length => correct_answer_length,
      }
    end
    q_node.search('calculatedformat_options/calculatedformat_option').each do |cr_node|
      correctanswerbase = parse_text(cr_node, 'correctanswerbase')
      correctanswerlengthint = parse_text(cr_node, 'correctanswerlengthint')
      correctanswerlengthfrac = parse_text(cr_node, 'correctanswerlengthfrac')
      correctanswerdigits = parse_text(cr_node, 'correctanswerdigits')
      exactdigits = parse_text(cr_node, 'exactdigits')
      correctanswershowbase = parse_text(cr_node, 'correctanswershowbase')
      correctanswergroupdigits = parse_text(cr_node, 'correctanswergroupdigits')

      question.calculatedformat_options = {
              :correctanswerbase => correctanswerbase,
              :correctanswerlengthint => correctanswerlengthint,
              :correctanswerlengthfrac => correctanswerlengthfrac,
              :correctanswerdigits => correctanswerdigits,
              :exactdigits => exactdigits,
              :correctanswershowbase => correctanswershowbase,
              :correctanswergroupdigits => correctanswergroupdigits,
      }
    end

    if question.answers.count > 1 && question.qtype == 'calculatedmulti'
      # turn multiple choice calculated questions into standard formula questions,
      # by ignoring the incorrect formulas
      if correct_formula = question.answers.detect{|a| a.fraction == 1}
        question.answers = [correct_formula]
      end
    end

    q_node.search('dataset_definitions/dataset_definition').each do |ds_node|
      var_name = parse_text(ds_node, 'name')
      question.dataset_definitions << {
          :name => var_name,
          :options => parse_text(ds_node, 'options'),
          :id => ds_node.attributes['id'].value,
          :category => parse_text(ds_node, 'category'),
          :itemcount => parse_text(ds_node, 'itemcount'),
      }
      ds_node.search('dataset_items/dataset_item').each do |ds_item_node|
        ident = parse_text(ds_item_node, 'number')
        var_set = question.var_sets.detect{|vs| vs[:ident] == ident}
        unless var_set
          var_set = {:ident => ident, :vars => {}}
          question.var_sets << var_set
        end
        var_set[:vars][var_name] = parse_text(ds_item_node, 'value')
      end
    end

    q_node.search('calculatedformat_records/calculatedformat_record').each do |cr_node|
      next unless parse_text(cr_node, 'answer') == question.answers.first.id.to_s

      question.correct_answer_format = parse_text(cr_node, 'correctanswerformat')
      question.correct_answer_length = parse_text(cr_node, 'correctanswerlength')
      question.tolerance = parse_text(cr_node, 'tolerance')
    end

    question
  end


  end
end
