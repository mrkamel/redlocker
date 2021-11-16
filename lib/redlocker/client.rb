# frozen_string_literal: true

module Redlocker
  # The `Redlocker::Client` class allows to easily acquire and keep distributed
  # locks using redis. The acquired lock gets automatically renewed every
  # second from a thread, i.e. its 5 second expiry value gets renewed in redis
  # every second, and it gets released when the given block finishes.
  #
  # @example
  #   RedlockerClient = Redlocker::Client.new(redis: Redis.new)
  #
  #   RedlockerClient.with_lock("some_lock", timeout: 5, delay: 1) do
  #     # lock acquired
  #   end

  class Client
    attr_reader :redis, :namespace

    # Creates a new `Redlocker::Client` instance.
    #
    # @param redis [Redis] The redis connection
    # @param namespace [String] An optional namespace to use for redis keys in
    #   addition to the default `redlocker:` namespace.
    #
    # @example
    #   RedlockerClient = Redlocker::Client.new(redis: Redis.new)

    def initialize(redis:, namespace: nil)
      @redis = redis
      @namespace = namespace
    end

    # Acquires the specified lock or raises a `Redlocker::TimeoutError` when
    # the lock can not be acquired within the specified `timeout`. You can pass
    # a `delay`, which specifies how long to wait between subsequent checks of
    # whether or not the lock is free. When the lock has been successfully
    # acquired, it gets refreshed every second, i.e. its expiry value of 5
    # seconds is refreshed within redis every second.
    #
    # @param name [String] The name of the lock. Will be used as the redis key
    #   for the lock.
    # @param timeout [Integer, Float] How long to wait for the lock. If the lock
    #   can not be acquired within that time, a `Redlocker::TimeoutError` will be
    #   raised.
    # @param delay [Integer, Float] How long to wait between subsequent checks
    #   of whether or not the lock is free. Default is 0.25 seconds.
    # @param block [Proc] The block which should be executed when the lock is
    #   acquired.
    #
    # @example
    #   RedlockerClient.with_lock("some_lock", timeout: 5, delay: 1) do
    #     # lock acquired
    #   end

    def with_lock(name, timeout:, delay: 0.25, &block)
      Lock.new(client: self, name: name, timeout: timeout, delay: delay).acquire(&block)
    end
  end
end
