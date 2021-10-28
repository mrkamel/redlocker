# frozen_string_literal: true

RSpec.describe Redlocker do
  describe '#lock' do
    let(:redlocker) { Redlocker.new(redis: redis) }
    let(:redis) { Redis.new }

    after { redis.flushdb }

    it 'acquires the lock and calls the block' do
      lock_id = nil
      pttl = nil

      redlocker.lock(name: 'some_lock', timeout: 3) do
        lock_id = redis.get('redlocker:some_lock')
        pttl = redis.pttl('redlocker:some_lock')
      end

      expect(lock_id).to match(/\A[0-9a-f]{32}\z/)
      expect(pttl).to be_between(4900, 5000)
    end

    it 'releases the lock when the block has finished' do
      redlocker.lock(name: 'some_lock', timeout: 3) do
        # nothing
      end

      expect(redis.exists?('redlocker:some_lock')).to eq(false)
    end

    it 'releases the lock when block raises' do
      begin
        redlocker.lock(name: 'some_lock', timeout: 3) do
          raise 'error'
        end
      rescue StandardError
        # nothing
      end

      expect(redis.exists?('redlocker:some_lock')).to eq(false)
    end

    it 'keeps the lock by updating the expire value every second' do
      allow(redis).to receive(:expire).and_call_original

      lock_id = nil
      pttl = nil

      redlocker.lock(name: 'some_lock', timeout: 3) do
        sleep 2.5

        lock_id = redis.get('redlocker:some_lock')
        pttl = redis.pttl('redlocker:some_lock')
      end

      expect(redis).to have_received(:expire).with('redlocker:some_lock', 5).exactly(2).times
      expect(lock_id).not_to be_nil
      expect(pttl).to be_between(4400, 4600)
    end

    it 'raises a TimeoutError when the lock can not be acquired' do
      thread = Thread.new do
        redlocker.lock(name: 'some_lock', timeout: 3) do
          sleep 3 # Block the lock for 3 seconds
        end
      end

      sleep 0.1

      expect do
        redlocker.lock(name: 'some_lock', timeout: 2) do
          # nothing
        end
      end.to raise_error(described_class::TimeoutError, 'Did not get lock within 2 seconds')
    ensure
      thread.join
    end

    it 'rescues errors while updating the lock' do
      lock_id = nil
      pttl = nil

      redlocker.lock(name: 'some_lock', timeout: 3) do
        # Let it fail 3 times
        allow(redis).to receive(:expire).and_raise('error')
        sleep 3.5

        # Let it finally succeed
        allow(redis).to receive(:expire).and_call_original
        sleep 1

        lock_id = redis.get('redlocker:some_lock')
        pttl = redis.pttl('redlocker:some_lock')
      end

      expect(redis).to have_received(:expire).with('redlocker:some_lock', 5).exactly(4).times
      expect(lock_id).not_to be_nil
      expect(pttl).to be_between(4400, 4600)
    end

    it 'uses the specified delay while acquiring the lock' do
      thread = Thread.new do
        redlocker.lock(name: 'some_lock', timeout: 3) do
          sleep 2
        end
      end

      sleep 0.1

      time = Time.now.to_f

      # It will try to acquire a lock immediately, after 800ms, after 1600ms
      # and should finally succeed after 2400ms
      redlocker.lock(name: 'some_lock', timeout: 3, delay: 0.8) do
        time = Time.now.to_f - time
      end

      expect(time).to be_between(2.4, 2.5)
    ensure
      thread.join
    end
  end
end
