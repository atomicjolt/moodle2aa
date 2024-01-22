module Moodle2AA::Learnosity::Converters
  class ExpressionConverter
    include ConverterHelper

    def initialize(moodle_question, moodle_course, html_converter)
      @moodle_question = moodle_question
      @moodle_course = moodle_course
      @html_converter = html_converter
      @expressions = {}
      
      # load all variables from question definition
      collect_vars(moodle_question)
      normalize_vars
      shuffle_vars
      #pp @vars
    end

    # update @vars with moodle_question variables
    def collect_vars(moodle_question)
      if moodle_question.type == 'calculatedquestiongroup' || 
          moodle_question.type == 'quizpage'
        moodle_question.questions.each do |subquestion|
          collect_vars(subquestion)
        end
      end
      @vars ||= []

      return unless moodle_question.respond_to? :dataset_definitions

      moodle_question.dataset_definitions.each do |dfn|
        # find a unique output name
        output_name = dfn[:name]
        cnt = 0
        if moodle_question.synchronize
          # synchronize, so share id
          id = dfn[:id]
          group = moodle_question.category_id
        else
          # not synchronized, so specific to question
          id = dfn[:id] + '-question-' + moodle_question.id
          group = 'question-' + moodle_question.id
        end
        while conflict = @vars.detect {|var| output_name == var[:output_name] && id != var[:datasetid]}
          #warn "Conflicting variable name #{output_name}"
          output_name = dfn[:name] + cnt.to_s
          cnt += 1
        end
        @vars << { name: dfn[:name],
                questionid: moodle_question.id,
                output_name: output_name,
                datasetid: id,
                group: group,
                values: [],
                itemcount: dfn[:itemcount].to_i,
        }
      end
      moodle_question.var_sets.each_with_index do |set, number|
        set[:vars].each do |name, value|
          var = @vars.detect {|var| var[:name] == name && var[:questionid] == moodle_question.id}
          if number < var[:itemcount]
            var[:values][number] = value
          else
            # deleted row that moodle threw in there for some reason
            @truncated_rows = true
          end
        end
      end
      # remove empty variables
      @vars = @vars.select { |set| set[:values].count != 0 }
    end
    
    def normalize_vars # make sure all vars have the same number of values
      maxcount = (@vars.map { |set| set[:values].count }).max
      mincount = (@vars.map { |set| set[:values].count }).min
      return '' if maxcount == 0 || !maxcount

      @vars.each do |set|
        count = set[:values].count
        Range.new(count+1,maxcount).each {|i| set[:values][i-1] = set[:values][(i-1)%count] }
      end
    end

    def has_shuffled_vars?
      groups = @vars.map {|set| set[:group]}
      groups = groups.uniq
      groups = groups.select {|group| group}  #filter nil group (derived formulas)
      return groups.length > 1
    end

    def shuffle_vars # shuffle vars so different groups aren't synchronized by accident
      # deterministic random
      #binding.pry if @vars.count > 10
      rng = Random.new(@moodle_question.id.to_i*4234)
      #binding.pry if @moodle_question.id == "2875-2876-2932-2945-2944-2946_quiz_130"
      groups = @vars.map {|set| set[:group]}
      groups = groups.uniq  #groups, in order of use in question
      groups.shift
      groups ||= []

      groups.each do |group|
        matching = @vars.select {|set| set[:group] == group}
        
        seed = (rng.rand*1000000).to_i
        matching.each do |set|
          # deterministic shuffle
          set[:values].shuffle!(random: Random.new(seed))
        end
      end

    end

    def convert_expression(expr, moodle_question)
      expr = expr.gsub(/&amp;/, '&')
      expr = expr.gsub(/&gt;/, '>')
      expr = expr.gsub(/&lt;/, '<')
      if m = expr.match(/^\{(%[^=]+)?(=)?(.+)\}$/)
        if m[2] == '='
          # e.g. {={x}+{y}}
          # e.g. {%7b={x}}  calculated format
          as_expr, as_var = convert_formula m[3], m[1], moodle_question, 'expr'
        else
          # e.g. {x}
          as_expr = as_var = convert_variable m[3], moodle_question
        end
      else
        #warn "Not a moodle expression: #{expr}"
        as_expr = as_var = expr
        warn "Not a moodle expression: #{expr}"
      end
      #print " Converted #{expr} -> #{as_expr}  ||  #{as_var}\n"
      [as_expr, as_var]  # as an expression ans as a single (synthetic) variable
    end

    def convert_answer(expr, format, moodle_question)
      convert_formula expr, format, moodle_question, 'ans'
    end
    
    # convert a single variable, e.g. {A}
    def convert_variable var, moodle_question

      if match = @vars.detect {|v| v[:name] == var && v[:questionid] == moodle_question.id }
        out = output_variable match
      else
        out = "{#{var}}"
        # probably a latex expression, ignore
        #warn "Unknown variable: #{var}"
      end
      out
    end
    def get_expression_variables
      @expressions
    end

    # convert a formula , e.g. {A} + {B}
    def convert_formula expr, format, moodle_question, type
      out = [expr, expr]
      if !format && m = expr.match(/^\s*\{([^{}]+)\}\s*$/)
        # Simple variable, not a calc format answer
        as_var = convert_variable m[1], moodle_question
        return [as_var, as_var]
      end
      begin
        as_expr = convert_formula_as_formula expr, format, moodle_question
        as_var = convert_formula_as_variable expr, format, moodle_question, type
        out = [as_expr, as_var]
        
        if m = as_var.match(/^\{\{var:(.*)\}\}$/)
          raw_var = m[1]
        else
          raise "Invalid as_var"
        end
        @expressions[raw_var] = expr + (format ? "  Format: #{format}" : "")
      rescue EvalError => e
        msg = "Error converting expression: #{expr}: #{e.message}"
        @error = msg
        warn msg
      end
      out
    end

    def convert_formula_as_formula(expr, format, moodle_question)
      formula_to_learnosity expr, format
    end

    def convert_formula_as_variable(expr, format, moodle_question, type)
      key = (expr+'__'+(format||'')).gsub(/\s+/, "")
      set = @vars.detect { |set| set[:name] == key && set[:questionid] == moodle_question.id }
      if !set
        # find unique output name
        cnt = 0
        while @vars.detect {|var| type+cnt.to_s == var[:output_name] }
          cnt += 1
        end
        output_name = type+cnt.to_s
        set = { name: key,
                questionid: moodle_question.id,
                output_name: output_name,
                datasetid: nil,
                values: [],
        }
        #binding.pry if 50458 == moodle_question.id.to_i
        calculate_data_values expr, format, set, moodle_question
        # see if this matches any other calculated column and reuse if so
        #@vars.select {|oldset| oldset[:output_name].match(/^#{type}/)}.each do |oldset|
        #  if set[:values].count > 1 && set[:values] == oldset[:values]
        #    # same as old one, so just reuse
        #    print "Reusing expression var #{expr} => #{oldset[:output_name]}, #{oldset[:name]}\n"
        #    return output_variable oldset
        #  end
        #end
        @vars << set
      end
      #print "New expression var #{expr} => #{set[:output_name]}, #{set[:name]}\n"
      output_variable set
    end

    def calculate_data_values(expr, format, set, moodle_question)
    #print "Evaluating #{expr}\n"
      # number of variants = maximum number of values over all variables
      maxcount = (@vars.map { |set| set[:values].count }).max
      maxcount ||= 0

      evalobj = MoodleEval.new
      @vars.each do |var|
        if var[:questionid] == moodle_question.id && var[:datasetid]
          evalobj.add_variable(var[:name], var[:values])
        end
      end
      
      Range.new(0,maxcount-1).each do |variant|
        evalobj.set_variant variant
        set[:values][variant] = evalobj.evaluate expr, format
      end
      #pp set[:values]
    end
    
    # Convert an expression from Moodle to Learnosity syntax.
    def formula_to_learnosity(expr, format)
      # TODO this isn't complete

      # pow(a,b) -> (a)^(b)
      # This isn't correct, but it'll work in many cases.
      expr = expr.gsub(/pow ?\((.*?),(.*?)\)/, '(\1)^(\2)')

      # trig conversion
      expr = expr.gsub(/deg2rad ?(?<re>\((?:(?>[^()]+)|\g<re>)*\))/, '\k<re>*Pi/180')
      expr = expr.gsub(/rad2deg ?(?<re>\((?:(?>[^()]+)|\g<re>)*\))/, '\k<re>*180/Pi')
      expr = expr.gsub(/pi ?\(\)/, 'Pi')

      if format && format.length > 0
        # TODO do something here?
        expr += "-- using format #{format}"
      end

      expr
    end

    def output_variable var
      "{{var:#{var[:output_name]}}}"
    end

    def has_nan?
      has_nan = false
      @vars.each do |set|
        set[:values].each {|value| has_nan ||= value.kind_of?(Float) && !value.finite?}
      end
      has_nan
    end

    def has_truncated_rows?
      @truncated_rows
    end
    

    def generate_dynamic_content_data
      # number of variants = maximum number of values over all variables
      maxcount = (@vars.map { |set| set[:values].count }).max
      return '' if maxcount == 0 || !maxcount
      
      unique = []
      @vars.each do |var|
         unique << var unless unique.detect {|var2| var2[:output_name] == var[:output_name]}
      end

      data = {}
      data['cols'] = unique.map { |set| set[:output_name] }
      data['rows'] = {}
      Range.new(1,maxcount).each do |cnt|
        ref = generate_unique_identifier_for("#{@moodle_question.id}+#{cnt}", "_dynamic-row")
        values = unique.map { |set| (set[:values][cnt-1]).to_s }
        data['rows'][ref] = { 'index' => cnt-1, 'values' => values }
      end
      data
    end

    def dump_variables
      return '' if @vars.count == 0
      out = []
      if has_shuffled_vars? 
        out << "SHUFFLED Dataset:"
      end
      out << (@vars.map {|v| v[:datasetid]?v[:output_name]:v[:output_name]+"="+v[:name]}).join(",").gsub(/[{}]/,'')

      out << "="*out[0].length
      Range.new(0,@vars[0][:values].count-1).each do |i|
        out << (@vars.map {|v| v[:values][i]}).join(",")
      end
      out.join "\n"
    end
    
    def dump_csv
      return '' if @vars.count == 0
      CSV.generate do |csv|
        csv << @vars.map {|v| v[:output_name]}

        Range.new(0,@vars[0][:values].count-1).each do |i|
          csv << @vars.map {|v| v[:values][i]}
        end
      end
    end

    def get_error
      if has_nan?
        out = ''
        out += @error if @error
        out += " Converted formulas contain Infinity or NaNs.  Please check by hand."
        out
      else
        @error
      end
    end
  end
end
