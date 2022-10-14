# frozen_string_literal: true

require_relative "lib/transfertpro/version"

Gem::Specification.new do |spec|
  spec.name = "transfertpro"
  spec.version = Transfertpro::VERSION
  spec.authors = ["Christian Lautier"]
  spec.email = ["clpublic@free.fr"]

  spec.summary = "Gem to access files stored in TransfertPro cloud provider"
  spec.description = "This gem allows basic file operations on TransfertPro and is not intended to mimic all the possibilities under the TransfertPro API"
  spec.homepage = "https://www.githib.com/maatinito/transfertpro/README.MD"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.3"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://www.githib.com/maatinito/transfertpro"
  spec.metadata["changelog_uri"] = "https://www.githib.com/maatinito/transfertpro/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "typhoeus"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
