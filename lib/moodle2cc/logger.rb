module Moodle2CC
  class Logger
    def self.logger
      Thread.current[:__moodle2cc_logger__] || ::Logger.new(STDOUT)
    end

    def self.logger=(logger)
      Thread.current[:__moodle2cc_logger__] = logger
    end

    def self.add_warning(message, exception)
      if logger.respond_to? :add_warning
        logger.add_warning(message, exception)
      elsif logger.respond_to? :warn
        if exception.respond_to? :full_message
          log = "#{message}\n#{exception.full_message}\n"
        else
          log = "#{message}\n#{exception.message}\n"
          if exception.backtrace
            exception.backtrace.each { |line| log << "    #{line}\n" }
          end
        end
        logger.warn log
      end
    end
  end
end
