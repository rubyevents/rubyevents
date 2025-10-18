# frozen_string_literal: true


module JobBuffer
  class << self
    def clear
      values.clear
    end

    def add(value)
      values << value
    end

    def values
      @values ||= []
    end

    def last_value
      values.last
    end
  end
end

class ActiveSupport::TestCase
  teardown do
    JobBuffer.clear
  end
end

class TestLogger < ActiveSupport::Logger
  def initialize
    @file = StringIO.new
    super(@file)
  end

  def messages
    @file.rewind
    @file.read
  end
end

module TestLoggerHelper
  def setup
    super
    JobBuffer.clear
    @old_logger = ActiveJob::Base.logger
    @logger = ActiveSupport::TaggedLogging.new(TestLogger.new)
    set_logger @logger
    ActiveJob::LogSubscriber.attach_to :active_job
  end

  def teardown
    super
    ActiveJob::LogSubscriber.log_subscribers.pop
    set_logger @old_logger
  end

  def set_logger(logger)
    ActiveJob::Base.logger = logger
  end
end