# Transfertpro

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/transfertpro`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'transfertpro'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install transfertpro

## Usage
First create a Transfertpro::FileSystem with api_key & secret given by Transfertpro
Optionaly, you may ask to connect to a different tenant: :default for usual tenant, :hds for health tenant

    api = Transfertpro::FileSystem.new(tp_api_key, tp_api_secret, :hds)

Second, connect with regular user mail & password 

    api.connect(user_mail, password)

Now you may download or upload file to shared space by using floowinf methods

    api.upload_shared_file('./test.txt','shared_directory/text')
    api.upload_shared_files('.', '*.pdf', 'shared_directory/bills')
    api.download_shared_file('shared_dir/bill_01.pdf', '.')
    api.download_shared_files('shared_dir', '*.pdf', '.')

All methods may throw Transferpro::Error in case a network error. Note that in case of network errors, the api try multiple times the transfert before giving up and sending exception. 

    rescue Transfertpro::Error => e
        puts e.message
        e.backtrace.first(11).each { |b| puts "   #{b}" }
        pp e.http_response if e.http_response
    end

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/maatinito/transfertpro.

## Licence

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
