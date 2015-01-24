# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timesheet/toggl/version'

Gem::Specification.new do |spec|
  spec.name          = "timesheet-toggl"
  spec.version       = Timesheet::Toggl::VERSION
  spec.authors       = ["Sergey Smagin"]
  spec.email         = ["smaginsergey1310@gmail.com"]
  spec.summary       = %q{Toggl integration for timesheet}
  spec.homepage      = "https://github.com/s-mage/timesheet-toggl"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_dependency 'curb'
  spec.add_dependency 'activesupport'
end
