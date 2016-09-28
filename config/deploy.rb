require 'mina/rails'
require 'mina/git'
require 'mina/rbenv'  # for rbenv support. (https://rbenv.org)
require 'mina/bundler'
# require 'mina/rvm'    # for rvm support. (https://rvm.io)

# Basic settings:
#   domain       - The hostname to SSH to.
#   deploy_to    - Path to deploy into.
#   repository   - Git repo to clone from. (needed by mina/git)
#   branch       - Branch name to deploy. (needed by mina/git)

set :domain, 'glz@188.166.233.94'
set :deploy_to, '/home/glz/mina_glz'
set :repository, 'git@github.com:Gaolz/mina_glz.git'
set :branch, 'master'
set :rbenv_path, '/home/glz/.rbenv'

set :shared_paths, fetch(:shared_paths, []).push('config/database.yml', 'config/secrets.yml', 'tmp/pids', 'tmp/sockets', 'log')


task :environment do
  invoke :'rbenv:load'
end

# All paths in `shared_dirs` and `shared_paths` will be created on their own.
task :setup => :environment do
  # command %{rbenv install 2.3.0}
  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/log"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/log"]
  queue! %(mkdir -p "#{deploy_to}/shared/tmp/sockets")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/tmp/sockets")
  queue! %(mkdir -p "#{deploy_to}/shared/tmp/pids")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/tmp/pids")

  queue! %[mkdir -p "#{deploy_to}/#{shared_path}/config"]
  queue! %[chmod g+rx,u+rwx "#{deploy_to}/#{shared_path}/config"]

  queue! %[touch "#{deploy_to}/shared/config/puma.rb"]
  queue! %[echo "-----> Be sure to edit 'shared/config/puma.rb'."]

  queue! %[touch "#{deploy_to}/#{shared_path}/config/database.yml"]
  queue! %[touch "#{deploy_to}/#{shared_path}/config/secrets.yml"]
  queue! %[touch "#{deploy_to}/#{shared_path}/config/puma.rb"]

  queue! %[touch "#{deploy_to}/shared/tmp/sockets/puma.state"]
  queue! %[echo "-----> Be sure to edit 'shared/tmp/sockets/puma.state'."]

  queue! %[touch "#{deploy_to}/shared/log/puma.stdout.log"]
  queue! %[echo "-----> Be sure to edit shared/log/puma.stdout.log'."]

  queue! %[touch "#{deploy_to}/shared/log/puma.stderr.log"]
  queue! %[echo "-----> Be sure to edit shared/log/puma.stderr.log'."]

  queue  %[echo "-----> Be sure to edit '#{deploy_to}/#{shared_path}/config/database.yml', 'secrets.yml' and puma.rb."]
end

desc "Deploys the current version to the server."
task :deploy => :environment do
  # uncomment this line to make sure you pushed your local branch to the remote origin
  # invoke :'git:ensure_pushed'
  deploy do
    # Put things that will set up an empty directory into a fully set-up
    # instance of your project.
    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'
    invoke :'deploy:cleanup'

    on :launch do
      queue "mkdir -p #{deploy_to}/#{current_path}/tmp/"
      queue "touch #{deploy_to}/#{current_path}/tmp/restart.txt"
    end
  end
end

namespace :puma do
  set :puma_env, fetch(:rails_env, 'production')
  set :puma_config, "#{deploy_to}/shared/config/puma.rb"
  set :puma_socket, "#{deploy_to}/shared/tmp/sockets/mina_glz.sock"
  set :puma_pid, "#{deploy_to}/shared/tmp/pids/puma.pid"
  set :puma_cmd, "bundle exec puma"

  desc "start puma"
  task start: :environment do
    queue 'echo "-----> start Puma"'
    queue! %[
      if [ -e '#{puma_pid}' ]; then
        echo 'Puma 已经运行，如需重启请使用‘mina puma:restart’';
      else
        cd #{deploy_to}/#{current_path} && #{puma_cmd} -C #{puma_config}
      fi
    ]
  end

  desc "stop puma"
  task stop: :environment do
    queue 'echo "------> 关闭 Puma"'
    queue! %[
      if [ -e '#{puma_pid}' ]; then
        kill -s SIGTERM `cat #{puma_pid}`
        rm -f '#{puma_pid}'
      else
        echo '成功关闭puma服务';
      fi
    ]
  end

  desc "restart puma"
  task restart: :environment do
    queue 'echo "------> 重启 Puma"'
    queue! %[
      if [ -e '#{puma_pid}' ]; then
        cd #{deploy_to}/#{current_path} && bundle exec pumactl -F #{deploy_to}/shared/config/puma.rb restart
        echo "向 puma 服务发送了 USR2 重启信号."
      else
        echo "puma 服务不存在，现在开启puma服务"
        cd #{deploy_to}/#{current_path} && #{puma_cmd} -C #{puma_config}
      fi
    ]
  end
end