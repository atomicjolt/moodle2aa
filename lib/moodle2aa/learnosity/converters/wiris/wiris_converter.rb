
require 'nokogiri'

module Moodle2AA::Learnosity::Converters::Wiris
  class WirisConverter < Moodle2AA::Learnosity::Converters::QuestionConverter
    SUBSTITUTION_VARIABLE_REGEX = /#([\D][\w\d]*)/

    DATA_TABLE_SCRIPT_TEMPLATE = <<~JS
      var PRECISION = {precision}
      seed({seed_value})
      setColumns({columns})

      {variable_declarations}


      for (var {loop_var} = 0; {loop_var} < NUM_ROWS; {loop_var}++) \{
      {algorithm}

        addRow([{row}])
      \}
    JS

    def convert_question_text(question)
      text = super
      text = text.gsub("mathcolor=\"#FF0000\"", "") # Quick hack to stop it from replacing the color

      node = Nokogiri::HTML(text)
      math_nodes = node.xpath("//math")


      if math_nodes.empty?
        # Probably plain-text
        text = replace_wiris_variables(text)
      else
        math_nodes.each do |math|
          replacement = replace_variables_in_math_ml(math) { |v| "{{var:#{v}}}" }
          math.replace(replacement)
        end

        text = node.to_xml
      end

      text
    end

    def replace_wiris_variables(text)
      text.gsub(SUBSTITUTION_VARIABLE_REGEX, "{{var:\\1}}")
    end

    def generate_datatable_script(question)
      return [nil, true] if question.algorithms_format == :none || question.substitution_variables.empty?

      script = DATA_TABLE_SCRIPT_TEMPLATE.dup
      script.gsub!('{precision}', (question.precision || 15).to_i.to_s)
      script.gsub!('{seed_value}', rand(10000).to_s)
      script.gsub!('{columns}', question.substitution_variables.to_a.to_s)
      script.gsub!('{variable_declarations}', question.script_variables.map { |v| "var #{v};" }.join("\n"))

      script.gsub!('{algorithm}', question.algorithms.map { |a| format_algorithm(a) }.join("\n"))
      script.gsub!('{row}', question.substitution_variables.map { |v| "format(#{v}, { precision: PRECISION })" }.join(','))

      if question.script_variables.include?('i')
        script.gsub!('{loop_var}', '_rowIndex_')
      else
        script.gsub!('{loop_var}', 'i')
      end

      unsupported_symbols = ['solve', 'numerical_solve', 'integrate', "_calc_apply", "wedge_operator", "_calc_plot"]

      is_valid = unsupported_symbols.none? { |f| script.include?(f) }

      puts '-----------------------------------'
      puts "Name: #{question.name}"
      puts "Type: #{question.type}"
      puts "Format: #{question.algorithms_format}"
      puts "Valid: #{is_valid}"
      puts '-----------------------------------'
      puts question.algorithms.join("\n")
      puts '-----------------------------------'
      puts script
      puts '-----------------------------------'

      [script, is_valid]
    end

    def format_algorithm(algorithm)
      algorithm.
        gsub(/\/#.+WirisQuizzes.+#\//m, ""). # Remove Wiris starting comment
        gsub(/\/#/, '/*'). # Multiline Comments start
        gsub(/#\//, '*/'). # Multiline Comments end
        gsub(/#/, "//"). # Single line comments
        gsub(/\^/, '**'). # Replace ^ with ** for exponentiation
        gsub(/if (.+) then\n/ , "if (\\1) {\n  "). # Replace if statements
        gsub(/else/, '} else {').
        gsub(/end/, '}'). # End of blocks
        gsub("_calc_approximate(,empty_relation)", ""). # Useless line
        gsub(/{(.+\,?)+}/, '[\1]'). # Arrays
        gsub(/\((\w+) subindex_operator\((.+)\)\)/) { |m| "#{$1}[#{$2} - 1]" }. # Array indexing
        # gsub(/wedge_operator/, '&&'). # Logical AND
        # The way that elements are being seperated is inconsistent
        # This normalizes it to be a comma seperated list
        gsub(/\((.+)\.\.(.+)\.\.(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+)\.\.(.+)\)/, "(\\1, \\2)").
        gsub(/\((.+);(.+);(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+);(.+)\)/, "(\\1, \\2)").
        gsub(/_calc_approximate\((.+),empty_relation\)/, "\\1"). # stips _calc_approximate function calls, returns the inner value
        gsub(":=", "="). # Wiris uses := for assignment without evaluating the right hand side
        split("\n")
        .map { |l| "  #{l}" }
        .join("\n")
    end

    # This is a really naive approach as it
    # assumes that the variables are not nested in any way
    # In practice this isn't ideal, but it's good enough for NJIT's use case
    def replace_variables_in_math_ml(root)
      return nil if root.nil?

      lines = []
      line = ""
      variable = ""
      replacing_variable = false

      root.children.each do |node|
        if node.text == "#"
          replacing_variable = true
          next
        end

        if replacing_variable
          if node.name == "mspace"
            replacing_variable = false
            val = yield(variable)
            lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math> #{val}"
            line = ""
            variable = ""
          else
            variable << node.text
          end
        else
          # Learnosity MathML doesn't support mfenced
          # so we replace it with parentheses explicitly
          if node.name == "mfenced"
            open = node.attributes["open"]&.value || "("
            close = node.attributes["close"]&.value || ")"
            line << "<mo>#{open}</mo>"
            line << node.children.to_xml
            line << "<mo>#{close}</mo>"
          else
            line << node.to_xml
          end
        end
      end

      if line != ""
        if variable != ""
          val = yield(variable)
          lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math> #{val}"
        else
          lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math>"
        end
      end

      lines.join("<br>")
    end
  end
end
