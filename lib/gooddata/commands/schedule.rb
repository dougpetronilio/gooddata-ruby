# encoding: UTF-8

require_relative '../core/core'

module GoodData::Command
  class Schedule
    class << self
      def list(pid = nil)
        return GoodData::Schedule.list(pid)
      end

      def show(pid = nil, sid = nil)
        return GoodData::Schedule.show(pid, sid)
      end

    end
  end
end