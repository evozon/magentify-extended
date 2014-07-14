### What's new?

* Disabled Git submodules by default
* Removed an unused library
* Fixed a Ruby/Capistrano bug
 
------

# Deploy Magento with Capistrano

This project is aimed to provide a simple tool that will deploy your Magento project to a set of environments.

## Requirements

* [Ruby](http://www.ruby-lang.org/) (<= 1.9.3)
* [Bundler](http://bundler.io/)
* [Capistrano](http://capistranorb.com/) (<= 2.15.5)
* [Git](http://git-scm.com/)
* [Composer](http://getcomposer.org/)

## Install

### Step 1

Install Ruby, Git and download Composer on your own. Google for howto's depending on your OS and environmnet :smile:

### Step 2

Download skeleton to your Magento project via Composer. For this, add the following to your **composer.json**:

```json
{
    "minimum-stability": "dev",
    "require": {
        "magento-hackathon/magento-composer-installer": "*",
        "evozon/magentify-extended": "*"
    },
    "repositories": [
        {
            "type": "git",
            "url":  "git@github.com:evozon/magentify-extended.git"
        }
    ],
    "extra": {
        "magento-root-dir": "./",
		"magento-deploystrategy": "copy"
    }
}
```

and run:

```shell
php composer.phar install
```

### Step 3

Install required Ruby gems and dependiencies via Bundler:

```shell
cd deploy/capistrano
sudo gem install bundler
bundle install
```

### Step 4

Configure Capistrano

Edit project under ```deploy/capistrano/deploy/project.rb``` and tasks or other actions under ```deploy/capistrano/deploy/deploy.rb```

Create a package folder under ```deploy/capistrano/deploy/``` where you can have a config file for each environment (example: ```deploy/capistrano/deploy/coolapp/production.rb```)

### Thanks to

* The guys who developed [Capistrano](http://capistranorb.com/)
* Alistair Stead from [Magentify](https://github.com/alistairstead/Magentify)
