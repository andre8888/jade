# commands used to deploy a Rails application
namespace :fly do
	task :ssh do
		sh 'fly ssh console'
	end

	task :console do
		sh 'fly ssh console --pty -C "/rails/bin/rails console"'
	end

	task :dbconsole do
		sh 'fly ssh console --pty -C "/rails/bin/rails dbconsole"'
	end

	# BUILD step:
	#  - changes to the filesystem made here DO get deployed
	#  - NO access to secrets, volumes, databases
	#  - Failures here prevent deployment
	task :build => 'assets:precompile'

	# RELEASE step:
	#  - changes to the filesystem made here are DISCARDED
	#  - full access to secrets, databases
	#  - failures here prevent deployment
	task :disable_database_environment_check do
		ENV['DISABLE_DATABASE_ENVIRONMENT_CHECK'] = '1'
	end

	task :release => 'db:migrate'

	task :db_drop => %w[fly:disable_database_environment_check db:drop]
	task :db_create => %w[fly:disable_database_environment_check db:create]
	task :db_migrate => %w[fly:disable_database_environment_check db:migrate]
	task :db_seed => %w[fly:disable_database_environment_check db:seed]
	task :db_reset => %w[fly:disable_database_environment_check db:drop db:create db:migrate]
end
