# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{stathat}
  s.version = "0.1.3"
  s.authors = ["StatHat"]
  s.description = %q{Easily post stats to your StatHat account using this gem.  Encapsulates full API.}
  s.email = %q{info@stathat.com}
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "lib/stathat.rb",
    "stathat.gemspec",
    "test/helper.rb",
    "test/test_stathat.rb"
  ]
  s.homepage = %q{http://github.com/patrickxb/stathat}
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.summary = %q{gem to access StatHat api}
  s.test_files = [
    "test/helper.rb",
    "test/test_stathat.rb"
  ]
end

