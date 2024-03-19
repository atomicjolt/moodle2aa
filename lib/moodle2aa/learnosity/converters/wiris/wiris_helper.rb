
module Moodle2AA::Learnosity::Converters::Wiris
  module WirisHelper
    DATA_TABLE_SCRIPT_TEMPLATE = <<~JS
      seed({seed_value})
      setColumns({columns})

      {variable_declarations}


      for (var {loop_var} = 0; {loop_var} < NUM_ROWS; {loop_var}++) \{
      {algorithm}

        addRow([{row}])
      \}
    JS

    def generate_datatable_script(question)
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
        gsub('{', '['). # Arays
        gsub('}', ']').
        gsub(/if (.+) then\n/ , "if (\\1) {\n  "). # Replace if statements
        gsub(/else/, '} else {').
        gsub(/end/, '}'). # End of blocks
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
          if node.name == "mfenced"
            line << "<mo>(</mo>"
            line << node.children.to_xml
            line << "<mo>)</mo>"
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
