require 'minitest/autorun'
require 'moodle2aa'
require 'stringio'

class TestUnitLogger < MiniTest::Test
  class MyLogger
    attr_accessor :message, :exception

    def add_warning(message, exception)
      @message   = message
      @exception = exception
    end
  end

  def test_it_logs_a_warning
    stdout = StringIO.new
    Moodle2AA::Logger.logger = ::Logger.new(stdout)
    ex = StandardError.new 'Kablooey!!!'
    Moodle2AA::Logger.add_warning 'got an error', ex
    assert_match /got an error/, stdout.string
    assert_match /Kablooey!!!/, stdout.string
  end

  def test_it_adds_a_warning
    my_logger = MyLogger.new
    Moodle2AA::Logger.logger = my_logger
    ex  = StandardError.new 'Kablooey!!!'
    msg = 'got an error'
    Moodle2AA::Logger.add_warning msg, ex
    assert_equal msg, my_logger.message
    assert_equal ex, my_logger.exception
  end
end
