#
# {SampleApplication} to install on local environment
#
# @link http://localhost/

server "localhost", :web, :db, :primary => true

# Folder to deploy to
set :deploy_to, "/var/www/sample-application"

# Branch to deploy
set :branch, "develop"

# SSH
set :user, "username"