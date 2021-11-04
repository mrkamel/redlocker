# frozen_string_literal: true

require 'redlocker/version'
require 'redlocker/client'
require 'redlocker/lock'
require 'redis'
require 'securerandom'

module Redlocker
  class TimeoutError < StandardError; end
end
