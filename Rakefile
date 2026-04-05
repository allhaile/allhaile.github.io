require "rake/testtask"

task default: [:build, :test]

desc "Build the Jekyll site"
task :build do
  sh "BUNDLE_GEMFILE='' /opt/rbenv/versions/3.3.6/bin/jekyll build"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_*.rb"]
  t.verbose = true
end
