
module Moodle2AA::Learnosity::Converters::Wiris
  module WirisHelper
    SUBSTITUTION_VARIABLE_REGEX = /#([\D][\w\d]*)\b/

    DATA_TABLE_SCRIPT_TEMPLATE = <<~JS
      seed({seed_value})
      setColumns({columns})

      {variable_declarations}


      for (var {loop_var} = 0; {loop_var} < NUM_ROWS; {loop_var}++) \{
      {algorithm}

        addRow([{row}])
      \}
    JS

    def replace_wiris_variables(text)
      text.gsub(SUBSTITUTION_VARIABLE_REGEX, '{{var:\1}}')
    end

    def generate_datatable_script(question)
      return [nil, true] if question.algorithms_format == :none || question.substitution_variables.empty?

      script = DATA_TABLE_SCRIPT_TEMPLATE.dup
      script.gsub!('{seed_value}', rand(10000).to_s)
      script.gsub!('{columns}', question.substitution_variables.to_a.to_s)
      script.gsub!('{variable_declarations}', question.script_variables.map { |v| "var #{v};" }.join("\n"))

      script.gsub!('{algorithm}', question.algorithms.map { |a| format_algorithm(a) }.join("\n"))
      script.gsub!('{row}', question.substitution_variables.map { |v| v }.join(','))

      if question.script_variables.include?('i')
        script.gsub!('{loop_var}', '_rowIndex_')
      else
        script.gsub!('{loop_var}', 'i')
      end

      # # Uses prettier to format the script
      # output = IO.popen('prettierd not-real.js', 'r+') do |io|
      #   io.puts(script)
      #   io.close_write
      #   io.read
      # end

      is_valid = !script.include?('//')

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
        gsub(/\((\w+) subindex_operator\((\w+)\)\)/) { |m| "#{$1}[#{$2} - 1]" }. # Array indexing
        # The way that elements are being seperated is inconsistent
        # This normalizes it to be a comma seperated list
        gsub(/\((.+)\.\.(.+)\.\.(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+)\.\.(.+)\)/, "(\\1, \\2)").
        gsub(/\((.+);(.+);(.+)\)/, "(\\1, \\2, \\3)").
        gsub(/\((.+);(.+)\)/, "(\\1, \\2)").
        gsub(":=", "="). # Wiris uses := for assignment without evaluating the right hand side
        split("\n").map { |l| "  #{l}" }.join("\n")
    end

    def convert_fomula_template(question)
      math_xml = Nokogiri::XML(question.answers.first.answer_text).root

      if math_xml.nil?
        return question.answers.first.answer_text
      end

      lines = []
      line = ""
      replacing_variable = false

      math_xml.children.each do |node|
        if node.text == "#"
          replacing_variable = true
          next
        end

        if replacing_variable
          if node.name == "mspace"
            replacing_variable = false
            lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math> {{response}}"
            line = ""
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
        lines << "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"> #{line} </math> {{response}}"
      end

      lines.join("<br>")
    end
  end
end
