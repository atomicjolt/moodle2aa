require 'byebug'

module Moodle2AA::Learnosity::Converters::Wiris
  module WirisAlgorithmConverter

    JS_TEMPLATE = <<~JS
      seed({seed_value})
      setColumns({columns})

      {variable_declarations}


      for (var i = 0; i < NUM_ROWS; i++) \{
      {algorithm}

        addRow([{row}])
      \}
    JS

    def self.convert_algorithms(question)
      script = JS_TEMPLATE.dup
      script.gsub!('{seed_value}', rand(10000).to_s)
      script.gsub!('{columns}', question.substitution_variables.to_a.to_s)
      script.gsub!('{variable_declarations}', question.script_variables.map { |v| "var #{v};" }.join("\n"))

      script.gsub!('{algorithm}', question.algorithms.map { |a| format_algorithm(a) }.join("\n"))
      script.gsub!('{row}', question.substitution_variables.map { |v| v }.join(','))

      # # Uses prettier to format the script
      # output = IO.popen('prettierd not-real.js', 'r+') do |io|
      #   io.puts(script)
      #   io.close_write
      #   io.read
      # end

      is_valid = !script.include?('//')

      puts '-----------------------------'
      puts "Question Name: #{question.name}"
      puts "Valid: #{is_valid}"
      puts '-----------------------------'
      puts script

      script
    end

    def self.format_algorithm(algorithm)
      algorithm.
        gsub(/\/#.+WirisQuizzes.+#\//m, ""). # Remove Wiris starting comment
        gsub(/\/#/, '/*'). # Comments start
        gsub(/#\//, '*/'). # Comments end
        gsub(/\^/, '**'). # Replace ^ with ** for exponentiation
        gsub('{', '['). # Arays
        gsub('}', ']').
        gsub(/if (.+) then\n/ , "if (\\1) {\n  "). # Replace if statements
        gsub(/else/, '} else {').
        gsub(/end/, '}'). # End of blocks
        split("\n").map { |l| "  #{l}" }.join("\n")
    end
  end
end
