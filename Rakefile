# -*- ruby -*-

require 'rubygems'
require 'hoe'

$:.unshift 'lib'
require 'rubygems/command'
require 'rubygems/commands/test_command'

Hoe.plugins.delete :rubyforge
Hoe.plugin :git

spec = Hoe.spec 'rubygems-test' do
  developer 'Erik Hollensbe', 'erik@hollensbe.org'
  developer 'Josiah Kiehl', 'bluepojo@gmail.com'

  self.version = Gem::Commands::TestCommand::VERSION
  
  self.rubyforge_name = nil

  self.description = <<-EOF
  This installs three major features:

  * a 'gem test' command.
  * the ability to test your gems on installation, and uninstall them if they fail testing.
  * A facility to upload your test results to http://www.gem-testers.org.
  EOF

  self.summary = 'commands and facilities for automated and user-contributed rubygems testing and reporting'
  self.url = %w[http://github.com/rubygems/rubygems-test]
  
  pluggable!

  require_ruby_version ">= 1.8.7"
  require_rubygems_version ">= 1.5.0"

  extra_deps << ['rake', '>= 0.8.7']

  desc "install a gem without sudo"
end

task :install => [:package] do
  sh "gem install pkg/#{spec.name}-#{spec.version}.gem"
end
# vim: syntax=ruby
