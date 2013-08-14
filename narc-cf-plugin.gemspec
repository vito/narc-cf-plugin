# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "narc-cf-plugin"
  spec.version       = '0.0.1.pre'
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Pivotal"]
  spec.email         = ["vcap-dev@googlegroups.com"]
  spec.description   = "CF command line tool to narc on applications"
  spec.summary       = "CF Narc"
  spec.homepage      = "http://github.com/cloudfoundry/narc-cf-plugin"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -- lib/* vendor/*`.split("\n")
  spec.require_paths = ["lib", "vendor"]

  spec.required_ruby_version = Gem::Requirement.new(">= 1.9.3")

  spec.add_dependency "cf", ">= 4.2.5", "< 5.0"
  spec.add_dependency "em-ssh", "~> 0.6.5"
  spec.add_dependency "highline", "~> 1.6.0"
end
