# Redlocker

[![Build](https://github.com/mrkamel/redlocker/workflows/test/badge.svg)](https://github.com/mrkamel/redlocker/actions?query=workflow%3Atest+branch%3Amaster)
[![Gem Version](https://badge.fury.io/rb/redlocker.svg)](http://badge.fury.io/rb/redlocker)

**Acquire and keep distributed locks alive using redis**

There are already quite some ruby libraries available which use redis for the
purpose of distributed locking, but they require you to specify the time
time-to-live of your locks. Contrary, Redlocker allows you to easily acquire
and keep distributed locks alive using redis. An acquired lock gets
automatically renewed every second from a thread, i.e. its 5 second expiry
value gets renewed in redis every second, and it gets released as soon as the
given block finishes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redlocker'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install redlocker

## Usage

Using Redlocker could not be easier:

```ruby
RedlockerClient = Redlocker::Client.new(redis: Redis.new)

RedlockerClient.lock(name: 'some_lock', timeout: 5) do
  # lock acquired
end
```

If the lock can not be acquired within the specified `timeout`, a
`Redlocker::TimeoutError` is raised.

When the block finishes or raises, the acquired lock gets freed.
 
You can optionally pass a `delay` when acquiring a lock, which specifies the
time to wait between subsequent calls which check in redis whether or not the
lock is free. Default is 0.25 seconds:

```ruby
RedlockerClient.lock(name: "some lock", timeout: 5, delay: 1) do
  # lock acquired
end
```

If you are using a shared redis, you can pass a namespace, which will be used for
prefixing redis keys in addition to the default `redlocker:` namespace.

```ruby
RedlockerClient = Redlocker::Client.new(redis: Redis.new, namespace: "my-namespace")
```

That's it.

## Reference docs

Please find the reference docs at
[http://www.rubydoc.info/github/mrkamel/redlocker](http://www.rubydoc.info/github/mrkamel/redlocker)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bundle exec rspec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mrkamel/redlocker.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
