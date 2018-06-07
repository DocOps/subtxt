
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "subtxt/version"

Gem::Specification.new do |spec|
  spec.name          = "subtxt"
  spec.version       = Subtxt::VERSION
  spec.authors       = ["Brian Dominick"]
  spec.email         = ["badominick@gmail.com"]

  spec.summary       = %q{A simple utility for converting multiple strings across multiple files, for conversion projects.}
  spec.description   = %q{A simple text conversion utility using regular expressions for searching and replacing multiple strings across multiple files, for conversion projects.}
  spec.homepage      = "https://github.com/DocOps/subtxt"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir['lib/**/*.rb']
  spec.bindir        = "bin"
  spec.executables   = ["subtxt"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
