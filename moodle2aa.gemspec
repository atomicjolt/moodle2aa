# -*- encoding: utf-8 -*-
require File.expand_path('../lib/moodle2aa/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Christopher Durtschi", "Kevin Carter", "Instructure", "Atomic Jolt"]
  gem.email         = ["christopher.durtschi@gmail.com", "cartkev@gmail.com", "eng@instructure.com", "matt.petry@atomicjolt.com", "justin.ball@atomicjolt.com"]
  gem.description   = %q{Migrates Moodle backup ZIP to Atomic Assessments}
  gem.summary   = %q{Migrates Moodle backup ZIP to Atomic Assessments}
  gem.homepage      = "https://github.com/atomicjolt/moodle2aa"
	gem.license = 'AGPLv3'

  gem.add_runtime_dependency "rubyzip", '>=1.0.0'
  gem.add_runtime_dependency "instructure-happymapper", '~> 0.5.10'
  gem.add_runtime_dependency "builder"
  gem.add_runtime_dependency "thor"
  gem.add_runtime_dependency "nokogiri"
  gem.add_runtime_dependency "rdiscount"
  gem.add_runtime_dependency "progress_bar"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "minitest"
  gem.add_development_dependency "rspec", "~> 3.0"
  gem.add_development_dependency "guard"
  gem.add_development_dependency "guard-bundler"
  gem.add_development_dependency "guard-minitest"
  gem.add_development_dependency "guard-rspec"
  gem.add_development_dependency "byebug"
  gem.add_development_dependency "pry"
  gem.add_development_dependency "pry-nav"


  gem.files         = Dir["{bin,lib}/**/*"] + ["Rakefile"]
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.name          = "moodle2aa"
  gem.require_paths = ["lib"]
  gem.version       = Moodle2AA::VERSION
end
