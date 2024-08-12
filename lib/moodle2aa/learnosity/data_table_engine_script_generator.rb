class Moodle2AA::Learnosity::DataTableEngineScriptGenerator
  DATA_TABLE_SCRIPT_TEMPLATE = <<~JS
    NUM_ROWS = {num_rows};
    seed({seed_value});
    setColumns({columns});

    var dataset = \{
    {dataset_declarations}
    \};

    {variable_declarations}

    for (var {loop_var} = 0; {loop_var} < NUM_ROWS; {loop_var}++) \{
    {algorithm}

      addRow([{row}]);
    \}
  JS

  def initialize
    @datasets = []
    @output_variables = []
    @answers = []
  end

  def generate
    script = DATA_TABLE_SCRIPT_TEMPLATE.dup

    script.gsub!('{num_rows}', @datasets.map { |d| d[:values].size }.min.to_s )
    script.gsub!('{seed_value}', rand(10000).to_s)
    script.gsub!('{columns}', @output_variables.to_s)
    script.gsub!('{dataset_declarations}', dataset_declarations)
    script.gsub!('{variable_declarations}', variable_declarations)
    script.gsub!('{algorithm}', format_body)
    script.gsub!('{row}', @output_variables.join(','))
    script.gsub!('{loop_var}', 'i')

    script
  end

  def add_dataset(name, values)
    @datasets << { name: name, values: values }
    @output_variables << name
  end

  def add_answer(name, formula)
    @answers << { name: name, formula: replace_vars(formula) }
    @output_variables << name
  end

  private

  def replace_vars(expr)
    expr.gsub(/\{([^{}=]+)\}/) do |match|
      $1
    end
  end

  def dataset_declarations
    lines = @datasets.map do |d|
      name = d[:name]
      values = d[:values].join(',')

      "  #{name}: [#{values}],"
    end

    lines.join("\n")
  end

  def variable_declarations
    (
      @datasets.map { |d| "var #{d[:name]};" } +
      @answers.map { |a| "var #{a[:name]};" }
    ).join("\n")
  end

  def format_body
    (
      @datasets.map { |d| "  #{d[:name]} = dataset.#{d[:name]}[i];" } +
      @answers.map { |a| "  #{a[:name]} = #{a[:formula]};" }
    ).join("\n")
  end
end
