#
# Main deploy recipe
#
# Tools:
# https://github.com/capistrano/capistrano
# https://github.com/railsware/caphub
# https://github.com/alistairstead/Magentify
#
# Read more about configurations:
# https://github.com/railsware/capistrano-multiconfig/README.md
#
# @author     Constantin Bejenaru <constantin.bejenaru@evozon.com>
# @copyright  Copyright (c) 2013 Evozon Systems (http://www.evozon.com)

require 'rexml/document'

set :scm,         :git
set :deploy_via,  :export

# Ask which tag to deploy; default = latest
# http://nathanhoad.net/deploy-from-a-git-tag-with-capistrano
set :branch do
  default_tag = `cd ../../ && git describe --abbrev=0 --tags`.split("\n").last

  tag = Capistrano::CLI.ui.ask 'Tag to deploy (make sure to push the tag first): [#{default_tag}] '
  tag = default_tag if tag.empty?
  tag
end unless exists?(:branch)

# Stages
#
# Configuration example for layout like:
# config/deploy/{NAMESPACE}/.../#{PROJECT_NAME}/{STAGE_NAME}.rb
set :stages,        ['development', 'testing', 'staging', 'production', 'local']
set :default_stage, 'local'

set(:stage)     { config_name.split(':').last }
set(:rails_env) { stage }
set(:rake)      { use_bundle ? "bundle exec rake" : "rake" }

# SSH
default_run_options[:pty] = true
set :use_sudo, false

# How many releases to keep
set :keep_releases,  3

# Rewrite shared_children, we don't need the Rails folder structure
set :shared_children, %w()

# Filesystem
set :app_symlinks,      ['/media', '/var', '/sitemaps', '/staging']
set :app_shared_dirs,   ['/app/etc', '/sitemaps', '/media', '/var', '/staging']
set :app_shared_files,  ['/app/etc/local.xml']

# Set permissions
set :permissions, {
  'ugoa+rwx' => {
    :regular => {
      :shared_path => %w(),
      :release_path => %w()
    },
    :recursive => {
      :shared_path => %w(/media /var /sitemaps /staging),
      :release_path => %w()
    }
  }
}

# netz98 magerun (http://github.com/netz98/n98-magerun/)
set :magerun_executable, 'n98-magerun.phar'
set :magerun_download, 'https://raw.github.com/netz98/n98-magerun/master/n98-magerun.phar'

# Dependencies
#depend :remote, :file, "#{shared_path}/app/etc/install.xml"

# Global Tasks
namespace :deploy do

  desc <<-DESC
    Prepares one or more servers for deployment. Before you can use any \
    of the Capistrano deployment tasks with your project, you will need to \
    make sure all of your servers have been prepared with `cap deploy:setup'. When \
    you add a new server to your cluster, you can easily run the setup task \
    on just that server by specifying the HOSTS environment variable:

      $ cap HOSTS=new.server.com deploy:setup

    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :setup, :except => { :no_release => true } do
    dirs = [deploy_to, releases_path, shared_path]
    # do not split by "/" and take the last part only
    dirs += shared_children.map { |d| File.join(shared_path, d) }

    run "#{try_sudo} mkdir -p #{dirs.join(' ')}"
    run "#{try_sudo} chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
  end

  desc <<-DESC
    Currently there is nothing special here, just rewriting the default task
    which assumes a Rails project is deployed but we are Magento powered.
  DESC
  task :finalize_update, :except => { :no_release => true } do

  end

  desc <<-DESC
    Make sure required folders and files have writing permission. \
    Currently, there is no option to make resources have different \
    writing permissions.
  DESC
  task :fix_permissions, :except => { :no_release => true } do
    logger.info 'Fixing permissions'

    commands = []
    permissions = fetch(:permissions, {})

    permissions.each {|access, type|
      type.each {|key, path|
        # is recursive?
        recursive = key == :recursive ? '-R' : ''

        dirs = []
        # Shared path
        if (nil != fetch(:shared_path, nil) && path.has_key?(:shared_path))
          dirs += path[:shared_path].map { |d| File.join(shared_path, d) }
        end

        # Release path
        if (nil != fetch(:release_path, nil) && path.has_key?(:release_path))
          dirs += path[:release_path].map { |d| File.join(release_path, d) }
        end

        # Current release
        if (nil != fetch(:current_release, nil) && path.has_key?(:current_release))
          dirs += path[:current_release].map { |d| File.join(current_release, d) }
        end

        # Previous release
        if (nil != fetch(:previous_release, nil) && path.has_key?(:previous_release))
          dirs += path[:previous_release].map { |d| File.join(previous_release, d) }
        end

        dirs.map do |dir|
          commands << "if [ -d #{dir} ]; then #{try_sudo} chmod #{recursive} #{access} #{dir}; fi"
        end
      }
    }

    run commands.join(' && ') if commands.any?
  end

  desc <<-DESC
    Create a version file and log deployed version/branch/tag and datetime
  DESC
  task :log_release, :except => { :no_release => true } do

    info = []
    info << "Tag/Branch: #{branch}"
    info << "Release name: #{release_name}"
    info << "Release path: #{release_path}"
    info << "Deploy date: $(date) $(ls -1 | wc -l)"

    run "cat /dev/null > #{release_path}/RELEASE"
    info.map do |nfo|
          run "echo \"#{nfo}\" >> #{release_path}/RELEASE"
    end
  end

  namespace :web do
    desc <<-DESC
      Disable the Magento install by creating the maintenance.flag in the web root.
    DESC
    task :disable, :roles => :web, :except => { :no_release => true } do
      on_rollback { run "rm -f #{current_path}/maintenance.flag" }
      mage::disable
    end

    desc <<-DESC
      Enable the Magento stores by removing the maintenance.flag in the web root.
    DESC
    task :enable, :roles => :web, :except => { :no_release => true } do
      mage::enable
    end
  end
end

# Improvements to 'mage' namespace
namespace :mage do
  desc <<-DESC
    Install netz98 magerun CLI tools (https://github.com/netz98/n98-magerun)
  DESC
  task :magerun, :roles => [:web, :app] do

    commands = []
    #commands << "cd #{current_path}"
    commands << "if [ ! -e #{current_path}/#{magerun_executable} ]; then curl -o #{current_path}/#{magerun_executable} #{magerun_download}; fi"
    commands << "chmod +x #{current_path}/#{magerun_executable}"
    run commands.join(' && ') if commands.any?

  end
  desc <<-DESC
    Flush the Magento Cache - works also with Memcached/Redis/etc.
  DESC
  task :cc, :roles => [:web, :app] do
    magerun
    run "cd #{current_path} && ./#{magerun_executable} cache:flush"
  end

  desc <<-DESC
    Flush the Magento Cache - filesystem only
  DESC
  task :cc_filesystem, :roles => [:web, :app] do
    run "if [ -d #{shared_path}/var/cache/ ]; then #{try_sudo} rm -rfv #{shared_path}/var/cache/*; fi"
    run "if [ -d #{shared_path}/var/full_page_cache/ ]; then #{try_sudo} rm -rfv #{shared_path}/var/full_page_cache/*; fi"
  end

  desc <<-DESC
    Install Magento with settings and credentials located in the following file:
      - install.xml (custom for Capistrano task)
    The XML file needs to be added before running this command.

    Location: {shared_path}/app/etc/
    Sample:   {current_path}/app/etc/install.xml.sample
    Note:     You have to run "deploy:setup" and "deploy"
                tasks before installing Magento

    @todo: If you know Ruby very well, or know someone who does,
           please refactor this task :))
  DESC
  task :install, :roles => [:web, :app] do
    # settings hash
    settings = {}

    filename = "#{shared_path}/app/etc/install.xml"

    exists = capture("if [ -e #{filename} ]; then echo 'true'; fi").strip
    raise Error, "Install file #{filename} does not exist!" unless exists == 'true'

    # Get settings for install
    file = capture "cat #{filename}"
    installXml = REXML::Document.new file

    install = [
      {
        :element => 'locale',
        :path => 'config/global/general/locale/code/text()',
        :default => 'en_US'
      },
      {
        :element => 'timezone',
        :path => 'config/global/general/locale/timezone/text()',
        :default => 'America/Los_Angeles'
      },
      {
        :element => 'default_currency',
        :path => 'config/global/general/currency/default/text()',
        :default => 'USD'
      },
      {
        :element => 'session_save',
        :path => 'config/global/session_save/text()',
        :default => 'files'
      },
      {
        :element => 'db_model',
        :path => 'config/global/resources/default_setup/connection/model/text()',
        :default => 'mysql4'
      },
      {
        :element => 'db_prefix',
        :path => 'config/global/resources/db/table_prefix/text()',
        :default => ''
      },
      {
        :element => 'db_host',
        :path => 'config/global/resources/default_setup/connection/host/text()',
        :default => 'localhost'
      },
      {
        :element => 'db_name',
        :path => 'config/global/resources/default_setup/connection/dbname/text()',
        :default => nil
      },
      {
        :element => 'db_user',
        :path => 'config/global/resources/default_setup/connection/username/text()',
        :default => nil
      },
      {
        :element => 'db_pass',
        :path => 'config/global/resources/default_setup/connection/password/text()',
        :default => nil
      },
      {
        :element => 'url',
        :path => 'config/global/web/base_url/unsecure/text()',
        :default => nil
      },
      {
        :element => 'secure_base_url',
        :path => 'config/global/web/base_url/secure/text()',
        :default => nil
      },
      {
        :element => 'use_rewrites',
        :path => 'config/global/web/seo/use_rewrites/text()',
        :default => 'yes'
      },
      {
        :element => 'use_secure',
        :path => 'config/global/web/secure/use_in_frontend/text()',
        :default => 'no'
      },
      {
        :element => 'use_secure_admin',
        :path => 'config/global/web/secure/use_in_adminhtml/text()',
        :default => 'no'
      },
      {
        :element => 'admin_frontname',
        :path => 'config/global/admin/routers/adminhtml/args/frontName/text()',
        :default => 'admin'
      },
      {
        :element => 'admin_username',
        :path => 'config/global/admin/system_account/username/text()',
        :default => nil
      },
      {
        :element => 'admin_password',
        :path => 'config/global/admin/system_account/password/text()',
        :default => nil
      },
      {
        :element => 'admin_lastname',
        :path => 'config/global/admin/system_account/lastname/text()',
        :default => nil
      },
      {
        :element => 'admin_firstname',
        :path => 'config/global/admin/system_account/firstname/text()',
        :default => nil
      },
      {
        :element => 'admin_email',
        :path => 'config/global/admin/system_account/email/text()',
        :default => nil
      },
      {
        :element => 'encryption_key',
        :path => 'config/global/crypt/key/text()',
        :default => nil
      }
    ];

    install.map do |cfg|
      value = REXML::XPath.first(installXml, cfg[:path])
      if value.nil?
        logger.info sprintf'Configuration value for "%s" not found, will use "%s" instead.', cfg[:element], cfg[:default] unless cfg[:default].nil?
        value = cfg[:default]
      end

      abort sprintf'Configuration value for "%s" not found! Can not install Magento.', cfg[:element] if value.nil?
      settings[cfg[:element]] = value
    end

    rmLocalXml = Capistrano::CLI.ui.ask('To install Magento, the current local.xml file needs to be removed.
A new one will be created. Are you sure you want to continue? [yes/no] ')

    if rmLocalXml === "yes"
      logger.info 'Installing Magento... grab a coffee and stand by'

      run "if [ -f #{current_path}/app/etc/local.xml ]; then #{try_sudo} rm -rfv #{current_path}/app/etc/local.xml; fi"
      run "if [ -f #{shared_path}/app/etc/local.xml ]; then #{try_sudo} rm -rfv #{shared_path}/app/etc/local.xml; fi"

      args = [
        "--license_agreement_accepted yes",
        "--locale \"#{settings["locale"]}\"",
        "--timezone \"#{settings["timezone"]}\"",
        "--default_currency \"#{settings["default_currency"]}\"",
        "--session_save \"#{settings["session_save"]}\"",
        "--db_model \"#{settings["db_model"]}\"",
        "--db_prefix \"#{settings["db_prefix"]}\"",
        "--db_host \"#{settings["db_host"]}\"",
        "--db_name \"#{settings["db_name"]}\"",
        "--db_user \"#{settings["db_user"]}\"",
        "--db_pass \"#{settings["db_pass"]}\"",
        "--url \"#{settings["url"]}\"",
        "--secure_base_url \"#{settings["secure_base_url"]}\"",
        "--use_rewrites \"#{settings["use_rewrites"]}\"",
        "--use_secure \"#{settings["use_secure"]}\"",
        "--use_secure_admin \"#{settings["use_secure_admin"]}\"",
        "--admin_frontname \"#{settings["admin_frontname"]}\"",
        "--admin_username \"#{settings["admin_username"]}\"",
        "--admin_password \"#{settings["admin_password"]}\"",
        "--admin_lastname \"#{settings["admin_lastname"]}\"",
        "--admin_firstname \"#{settings["admin_firstname"]}\"",
        "--admin_email \"#{settings["admin_email"]}\"",
        "--encryption_key \"#{settings["key"]}\""
      ]

      run "php #{current_path}/install.php -- " + args.join(" ")

      # Make the local.xml switch
      run "#{try_sudo} cp -f #{current_path}/app/etc/local.xml #{shared_path}/app/etc/local.xml"
      run "#{try_sudo} rm -f #{current_path}/app/etc/local.xml"
      run "#{try_sudo} ln -s #{shared_path}/app/etc/local.xml #{current_path}/app/etc/local.xml"

      logger.info "Magento is now installed, you can check it under #{settings["url"]}"
    end
  end
end

# Hook deploy:setup and mage:setup
after 'mage:setup', 'deploy:fix_permissions'
after 'mage:setup', 'mage:cc_filesystem'

# Hook mage:install
after 'mage:install', 'mage:magerun'

# Hook deploy:finalize_updates
before 'deploy:finalize_update',  'deploy:fix_permissions'
after 'deploy:finalize_update',   'deploy:log_release'
after 'deploy:restart',           'mage:cc'

# Remove old releases
after :deploy, 'deploy:cleanup'
