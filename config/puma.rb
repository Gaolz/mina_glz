app_path = File.expand_path( File.join(File.dirname(__FILE__), '..'))
# Change to match your CPU core count
workers 1
#
# # Min and Max threads per worker
threads 1, 6
#
# # Default to production
rails_env = ENV['RAILS_ENV'] || "production"
environment rails_env
#
# # Set up socket location
bind "unix://#{app_path}/tmp/sockets/pumactl.sock"
#
# # Logging
stdout_redirect "#{app_path}/log/puma.stdout.log", "#{app_path}/log/puma.stderr.log", true
#
# # Set master PID and state locations
pidfile "#{app_path}/pids/puma.pid"
state_path "#{app_path}/tmp/sockets/puma.state"
activate_control_app
#
on_worker_boot do
  require "active_record"
  ActiveRecord::Base.connection.disconnect! rescue ActiveRecord::ConnectionNotEstablished
  ActiveRecord::Base.establish_connection(YAML.load_file("#{app_path}/config/database.yml")[rails_env])
end
