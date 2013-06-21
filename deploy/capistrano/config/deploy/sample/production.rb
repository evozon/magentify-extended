#
# {SampleApplication} to install on production environment
#
# @link http://localhost/

server "localhost", :web, :db, :primary => true

# Folder to deploy to
set :deploy_to, "/var/www/sample"

# SSH
set :user, "username"