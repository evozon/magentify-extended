#
# {SampleApplication} to install on testing/QA environment
#
# @link http://localhost/

server "localhost", :web, :db, :primary => true

# Folder to deploy to
set :deploy_to, "/var/www/sample"

# Branch to deploy
set :branch, "develop"

# SSH
set :user, "username"