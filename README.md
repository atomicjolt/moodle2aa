# Moodle2AA

moodle2aa will convert Moodle 1.9 backup files into Atomic Assessments compliant JSON.

Moodle information: http://moodle.org/

[Atomic Assessments](https://www.atomicjolt.com/atomic-assessments)
[Getting started with Atomic Assessments](https://support.atomicjolt.com/knowledgebase/getting-started-with-atomic-assessments)

Use the [Github Issues](https://github.com/atomicjolt/moodle2aa/issues?state=open)
for feature requests and bug reports.

## Legal

This project is derived from the [moodle2aa](https://github.com/instructure/moodle2aa) gem.

## Installation/Usage

### Command line

Install RubyGems on your system, see http://rubygems.org/ for instructions.
Once RubyGems is installed you can install this gem:

    $ gem install moodle2aa

Convert a moodle .zip into Atomic Assessments format

    $ moodle2aa migrate <path-to-moodle-backup> <path-to-aa-export-directory>

### In a Ruby application

Add this line to your application's Gemfile and run `bundle`:

    gem 'moodle2aa'

Require the library in your project and use the migrator:

```ruby
require 'moodle2aa'
migrator = Moodle2AA::Migrator.new moodle_zip_path, destination_path
migrator.migrate
```

## Caveats

This is not a complete solution and not all Moodle information will be migrated.

## Contributing

Run the tests:

    $ bundle exec rake

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
