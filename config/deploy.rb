require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'
require 'securerandom'

# Basic settings:
set :application_name, 'rails-demo'
set :domain, '167.99.244.126'
set :user, fetch(:application_name)
set :deploy_to, "/home/#{fetch(:user)}/app"
set :repository, 'https://github.com/omstrimed/demo.git'
set :branch, 'main'
set :forward_agent, true

# Shared files and directories
set :shared_files, fetch(:shared_files, []).push('config/database.yml')
set :shared_dirs, fetch(:shared_dirs, []).push('public/packs', 'node_modules')

task :remote_environment do
  ruby_version = File.read('.ruby-version').strip
  raise "Couldn't determine Ruby version: Do you have a file .ruby-version in your project root?" if ruby_version.empty?

  # Ensure rbenv is available in the Mina environment
  command %[export PATH="$HOME/.rbenv/bin:$PATH"]
  command %[eval "$(rbenv init -)"]
  command %[rbenv install #{ruby_version} || rbenv local #{ruby_version}]  # Ensure Ruby version is installed
  command %[rbenv local #{ruby_version}]
end

# Setup task
task :setup do
  in_path(fetch(:shared_path)) do
    command %[mkdir -p config]

    # Create database.yml for Postgres if it doesn't exist
    path_database_yml = "config/database.yml"
    database_yml = %[production:\n  database: #{fetch(:user)}\n  adapter: postgresql\n  pool: 5\n  timeout: 5000]
    command %[test -e #{path_database_yml} || echo "#{database_yml}" > #{path_database_yml}]

    # Create secrets.yml if it doesn't exist
    path_secrets_yml = "config/secrets.yml"
    secrets_yml = %[production:\n  secret_key_base: #{SecureRandom.hex(64)}]
    command %[test -e #{path_secrets_yml} || echo "#{secrets_yml}" > #{path_secrets_yml}]

    # Remove others-permission for config directory
    command %[chmod -R o-rwx config]
  end
end

desc "Deploys the current version to the server."
task :deploy do
  deploy do
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      # Uncomment and adjust the following line if you need to restart a service
      # command "sudo systemctl restart #{fetch(:user)}"
    end
  end
end
