# frozen_string_literal: true

require 'redlocker/version'
require 'redis'
require 'securerandom'

# The `Redlocker` class allows to easily acquire and keep locks using redis.
# The acquired lock gets automatically renewed every second, i.e. its 5 second
# expiry value gets renewed in redis every second, and it gets released when
# the given block finishes.
#
# @example
#   redlocker = Redlocker.new(redis: Redis.new)
#
#   redlocker.lock(name: 'some_lock', timeout: 5) do
#     # lock acquired
#   end

class Redlocker
  class TimeoutError < StandardError; end

  class Lock
    def initialize(redis:, name:, timeout:, delay:)
      @redis = redis
      @name = name
      @timeout = timeout
      @delay = delay
      @id = SecureRandom.hex
    end

    def acquire(&block)
      raise(TimeoutError, "Did not get lock within #{@timeout} seconds") unless acquire_lock

      begin
        keep_lock(&block)
      ensure
        release_lock
      end
    end

    private

    def release_lock
      @redis.del(redis_key_name) if @redis.get(redis_key_name) == @id
    end

    def keep_lock(&block)
      stop = false
      mutex = Mutex.new

      Thread.new do
        until mutex.synchronize { stop }
          begin
            sleep 1

            @redis.expire(redis_key_name, 5)
          rescue StandardError
            # nothing
          end
        end
      end

      block.call
    ensure
      mutex.synchronize do
        stop = true
      end
    end

    def acquire_lock
      start = Time.now.to_f

      loop do
        return true if try_acquire_lock
        return false if Time.now.to_f - start > @timeout

        sleep @delay
      end
    end

    def try_acquire_lock
      get_lock_script = <<~GET_LOCK_SCRIPT
        local lock_key_name, id, expire_value = ARGV[1], ARGV[2]

        local cur = redis.call('get', lock_key_name)

        if not cur then
          redis.call('setex', lock_key_name, 5, id)

          return true
        elseif cur == id then
          redis.call('expire', lock_key_name, 5)

          return true
        end

        return false
      GET_LOCK_SCRIPT

      @redis.eval(get_lock_script, argv: [redis_key_name, @id])
    end

    def redis_key_name
      "redlocker:#{@name}"
    end
  end

  # Create a new `Redlocker` instance.
  #
  # @param redis [Redis] The redis connection
  #
  # @example
  #   Redlocker.new(redis: Redis.new)

  def initialize(redis:)
    @redis = redis
  end

  # Acquires the specified lock or raises a `Redlocker::TimeoutError` when the
  # lock can not be acquired within the specified `timeout`. You can pass a
  # `delay`, which specifies how long to wait between subsequent checks of
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
  #   redlocker.lock(name: "some lock", timeout: 5, delay: 1) do
  #     # lock acquired
  #   end

  def lock(name:, timeout:, delay: 0.25, &block)
    Lock.new(redis: @redis, name: name, timeout: timeout, delay: delay).acquire(&block)
  end
end
