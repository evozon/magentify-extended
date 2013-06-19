### What's new?

* Removed an unused library
* Fixed a Ruby/Capistrano bug
 
------

# Deploy Magento with Capistrano

This project is aimed to provide a simple tool that will deploy your Magento project to a set of environments.

## Requirements

* [Ruby](http://www.ruby-lang.org/)
* [Git](http://git-scm.com/)
* [Composer](http://getcomposer.org/)

## Install

First you need to add the deploy code and Capistrano recipes to your Magento project. For this, add the following to your **composer.json**:

    {
        "minimum-stability": "dev",
        "require": {
            "evomage/capistrano": "*"
        },
        "repositories": [
            {
                "type": "vcs",
                "url":  "git@evogit.evozon.com:evomage/composer-mage-module-installer.git"
            },
            {
                "type": "vcs",
                "url":  "git@evogit.evozon.com:evomage/capistrano.git"
            }
        ],
        "extra": {
            "magento-root-dir": "./",
    		"magento-deploystrategy": "copy"
        }
    }

### Thanks to

* The guys who developed [Capistrano](http://capistranorb.com/)
* Alistair Stead from [Magentify](https://github.com/alistairstead/Magentify)

### Contact

If you have a bug report, a feedback, a suggestion, you can contact me using [email](mailto:constantin.bejenaru@evozon.com)