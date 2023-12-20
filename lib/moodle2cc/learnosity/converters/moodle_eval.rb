# bitwise ops on floats, like in php :)
class Float 
  def &(b)
    (self.to_i & b.to_i).to_f
  end
  def |(b)
    (self.to_i | b.to_i).to_f
  end
  def ^(b)
    (self.to_i ^ b.to_i).to_f
  end
  def ~
    (~(self.to_i)).to_f
  end
  def >>(b)
    (self.to_i >> b.to_i).to_f
  end
  def <<(b)
    (self.to_i << b.to_i).to_f
  end
end

module Moodle2CC::Learnosity::Converters
  class MoodleEval

    def initialize
      @_variant = 0
      @_varmap = {}
    end

    def set_variant(variant)
      @_variant = variant
    end

    def _to_number(str)
      str.to_f
    end

    def add_variable(name, values)
      values = values.map {|v| _to_number(v)}
      varalias = "v#{@_varmap.length}"
      @_varmap[name] = varalias
      define_singleton_method(varalias.to_sym) {values[@_variant]}
    end

    #def method_missing(name, *args)
    #  puts "MISSING: #{name}"
    #  pp args
    #end

    def _replace_vars(expr)
      expr.gsub(/\{([^{}=]+)\}/) do |match|
        if @_varmap[$1]
          "("+@_varmap[$1]+")"
        else
          match
        end
      end
    end

    def _fix_expression(expr)
      
      # deal with php falsy values and ? :
      out = expr
      i = 0
      while i < out.length
        # look backwards. ? has very low precidence
        if out[i] == '?'
          j = i-1
          level = 0
          while j >=0 
            if out[j] == ')'
              level += 1
            elsif out[j] == '('
              level -= 1
              if level < 0
                break
              end
            elsif (out[j] == ',' || out[j] == ':') && level == 0
              break;
            end
            j -= 1
          end
          out = out[0,j+1]+'to_boolean('+out[j+1,i-j-1]+')?'+out[i+1,out.length];
          i += 12
        end
        i += 1
      end
      #pp expr + "=>" + out

      # very specific fix for 252  handle  (v1) && (v2)
      out = out.gsub(/(\(v[0-9]+\)) *(\&\&|\|\|) *(\(v[0-9]+\))/, "(\\1 != 0) \\2 (\\3 != 0)")
      
      out = out.gsub(/\s+\(/, "(")  #remove whitespace before parens, it's not needed and can confuse ruby
      # add .0 to all integers to force float conversion
      out = out.gsub(/([^.0-9a-zA-Z_]|^)([0-9]+)((?=[^.0-9x])|$)/, "\\1\\2.0")  #remove whitespace before parens, it's not needed and can confuse ruby
      out = out.gsub(/([0-9]+[eE]-?[0-9]+)[.]0/, "\\1")  #Oops, need to fix anything like 3.4e-4.0 
      # decimal .1 needs leading 0
      out = out.gsub(/([^0-9]|^)[.]([0-9])/, "\\1 0.\\2")
      #print "CHECK #{expr} : #{old}\n" if expr != old
                    
      out
      # All ? needs a space in ruby 
      #out = out.gsub(/\?/, " ? ")
    end

    def to_boolean(a)
      # emulate php behavior
      if !a || a == 0 || a === "0" || a === ''
        false
      else
        true
      end
    end

    def evaluate(expr,format)
      
      expr = _replace_vars expr
      expr = _fix_expression expr
      #puts "Evaluate #{expr} => #{new}"

      # We should really do some sanitation, but leaving as an eval for now
      
      
      result = nil
      begin
        self.instance_eval "result=(#{expr})"
      rescue RangeError => e
        warn "Range error #{expr}: "+e.message
        result = Float::NAN
      rescue Exception => e
        #warn "Error evaluating #{expr}: "+e.message
        raise EvalError.new("Error parsing expression #{expr}:\n"+e.message)
      end
      if result.kind_of?(Float) && !result.finite?
        warn "Got : "+result.to_s
      end
      if format && !(result.kind_of?(Float) && !result.finite?)
        #print "Format #{format}  #{result} => "
        result = format_by_fmt(format, result)
        #print "#{result}\n"
      end
      #puts "  RESULT: #{out}"

      # round result, if a float
      if result.kind_of?(Float) && result.finite? && (result % 1 != 0)
        # 8 digits, I guess.  Be careful about numbers close to 0
        digits = 8
        exp = Math.log10(result.abs).ceil
        if exp >= 0
          result = result.round(digits)  # away from 0, digits past the decimal
        else
          result = result.round(digits-exp)  # close to 0, sig figs in this case
        end
      end

      #if it's an integer, make it an integer, so we don't get a '.0' in the output
      if result.kind_of?(Float) && result.finite? && round(result) == result
        result = Integer(result)
      end

      #emulate php behavior
      if result === true
        result = 1
      elsif result === false
        result = 0
      end

      result
    end
    
    def format_by_fmt(fmt, x) 
        groupre = '(?:[,_])?'
        regex = /^%([pP]?)((?:[,_])?)(\d*)(?:\.(\d+))?([bodxBODX])$/
        #if (preg_match(regex, fmt, regs)) 
        if (m = regex.match(fmt))
            #list(fullmatch, showprefix, group, lengthint, lengthfrac, basestr) = regs
            fullmatch, showprefix, group, lengthint, lengthfrac, basestr = m[0], m[1], m[2], m[3], m[4], m[5]

            base = 0
            basestr = strtolower(basestr)
            if (basestr == 'b') 
                base = 2

            elsif (basestr == 'o') 
                base = 8

            elsif (basestr == 'd') 
                base = 10

            elsif (basestr == 'x') 
                base = 16

            else 
                raise "coding error"
            end

            lengthint = intval(lengthint)
            lengthfrac = intval(lengthfrac)

            if (group == ',') 
                groupdigits = 3
            elsif (group == '_') 
                groupdigits = 4
            else 
                groupdigits = 0
            end

            showprefix = strtolower(showprefix)
            if (showprefix == 'p') 
                showprefix = true
            else 
                showprefix = false
            end

            return qtype_calculatedformat_format_in_base(
                x, base, lengthint, lengthfrac, groupdigits, showprefix
            )
        end
        warn "Invalid format #{fmt}"
        x

        #// Not a valid format.
    end
    
    def qtype_calculatedformat_format_in_base( x, base=10, lengthint=1, lengthfrac=0, groupdigits=0, showprefix=false )
      digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      
      masklengthint = lengthint

      answer = x
      sign = ''

      if ((base == 2) || (base == 8) || (base == 16))
          #// Mask to exact number of digits, if required.
          answer = qtype_calculatedformat_mask_value(
              answer, base, masklengthint, lengthfrac
          )

          #// Round properly to correct # of digits.
          answer *= pow(base, lengthfrac)
          answer = intval(round(answer))

       else
          #// Convert to positive answer.
          if (answer < 0)
              answer = -answer
              sign = '-'
          end
      end

      if (base == 2) 
        x = sprintf('%0' + (lengthint + lengthfrac).to_s + 'b', answer)
      elsif (base == 8) 
        x = sprintf('%0' + (lengthint + lengthfrac).to_s + 'o', answer)
      elsif (base == 16) 
        x = sprintf('%0' + (lengthint + lengthfrac).to_s + 'X', answer)
      else 
          width = lengthint
          if (lengthfrac > 0) 
              #// Include fractional digits and decimal point.
              width += lengthfrac + 1
          end
          x = sprintf('%0' + width.to_s + '.' + lengthfrac.to_s + 'f', answer)
      end

      if (base != 10) 
          #// Insert radix point if there are fractional digits.
          if (lengthfrac > 0) 
              #x = substr_replace(x, '.', -lengthfrac, 0)
            x = x.insert(-(lengthfrac+1), '.')
          end
      end

      if ((base == 2) || (base == 8) || (base == 16)) 
          if (masklengthint < 1) 
              #// Strip leading zeros.
              #x = ltrim(x, '0')
              x = x.gsub(/^0+/, '')

              if (strlen(x) < 1) 
                  x = '0'

              elsif (x[0] == '.') 
                  x = '0' . x
              end
          end
      end

      if (groupdigits > 0) 
          #parts = explode('.', x, 2)
          parts = x.split('.', 2)
          if (parts.count > 1) 
              integer = parts[0]
              fraction = parts[1]
          else 
              integer = x
              fraction = ''
          end

          #// Add group separator(s).
          nextgrouppos = strlen(integer) - groupdigits
          while (nextgrouppos > 0) 
              #integer = substr_replace(integer, '_', nextgrouppos, 0)
              integer = integer.insert(nextgrouppos, '_')
              nextgrouppos -= groupdigits
          end

          if (strlen(fraction) > 0) 
              x = integer + '.' + fraction
          else 
              x = integer
          end
      end

      prefix = ''
      if (showprefix) 
          if (base == 2) 
              prefix = '0b'

          elsif (base == 8) 
              prefix = '0o'

          elsif (base == 10) 
              prefix = '0d'

          elsif (base == 16) 
              prefix = '0x'
          end
      end

      return sign + prefix + x
    end

    def qtype_calculatedformat_mask_value(x, base, lengthint, lengthfrac) 
      if ((base != 2) && (base != 8) && (base != 16)) 
          raise "Illegal base"
      end

      numbits = 0;
      #for (mask = 1; mask < base; mask <<= 1) 
      #    numbits++;
      #end
      mask = 1
      while mask < base
          numbits+=1
          mask = mask << 1
      end

      if (lengthint < 1) 
          return x
      end

      powbase = pow(base, lengthfrac)

      #// Round properly to correct # of digits.
      x *= powbase
      x = intval(round(x))

      numbits *= (lengthint + lengthfrac)

      #// Construct mask with exact bit length.
      mask = 0
      #for (i = 0; i < numbits; i++) 
      #    mask <<= 1;
      #    mask |= 1;
      #end
      i = 0
      while i < numbits
        i+=1
        mask <<= 1
        mask |= 1
      end

      #// Mask off extra bits.
      x &= mask

      #// Convert back to fractional number.
      x /= powbase

      return x
    end

    ####  php/moodle functions for use in expressions ####

    def max(*args) args.max end
    def min(*args) args.min end

    def acos(a) Math.acos(a) end
    def acosh(a) Math.acosh(a) end
    def asin(a) Math.asin(a) end
    def asinh(a) Math.asinh(a) end
    def atan2(a,b) Math.atan2(a,b) end
    def atan(a) Math.atan(a) end
    def atanh(a) Math.atanh(a) end
    def cos(a) Math.cos(a) end
    def cosh(a) Math.cosh(a) end
    def sin(a) Math.sin(a) end
    def sinh(a) Math.sinh(a) end
    def tan(a) Math.tan(a) end
    def tanh(a) Math.tanh(a) end
    def pi() Math::PI end
    def log10(a) Math.log10(a) end
    #def log1p(a)  end
    def log(a) Math.log(a) end
    def exp(a) Math.exp(a) end
    #def expm1(a) Math.abs(a) end
    def sqrt(a) Math.sqrt(a) end

    def abs(a) a.abs end
    def floor(a) a.floor end
    def ceil(a) a.ceil end
    def round(a, b=0) a.round(b.to_i) end
    def intval(a) a.to_i end
    def pow(a,b) _to_number(a**b) end
    def fmod(a,b) a%b end

    def _require_int(a) raise( RangeError, "Not an integer") if a.to_f != a.to_i end

    def decbin(a) _require_int(a) ; ("%b" % a).to_i end
    def bindec(a) _require_int(a) ; a.to_s.to_i(2) end
    def decoct(a) _require_int(a) ; ("%o" % a).to_i end
    def octdec(a) _require_int(a) ; a.to_s.to_i(8) end
    def deg2rad(a) a*pi()/180 end
    def rad2deg(a) a*180/pi() end

    def is_finite(a) (a.to_f).finite? end
    def is_infinite(a) (a.to_f).infinite? end
    def is_nan(a) (a.to_f).nan? end
    
    def strlen(a) (a.to_s).length end
    def strtolower(a) (a.to_s).downcase end
    
    #def rand(a) Math.abs(a) end

  end
end
