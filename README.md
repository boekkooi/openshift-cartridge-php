# Openshift PHP Plugin Cartridge
Welcome to the world of [PHP-FPM](http://php.net/manual/en/book.fpm.php) within [openshift](https://www.openshift.com/).

Currently this cartridge works well the [boekkooi NGINX cartridge](https://github.com/boekkooi/openshift-cartridge-nginx).

You can add this cartridge to your application using:
```BASH
rhc cartridge add -a myapp http://cartreflect-claytondev.rhcloud.com/github/boekkooi/openshift-cartridge-php
```

If you want to install a specific PHP version you can add `--env OPENSHIFT_PHP_VERSION=<version>` to the command.
For example to install PHP 5.5.22 you can use:
```BASH
rhc cartridge add -a myapp --env OPENSHIFT_PHP_VERSION=5.5.22 http://cartreflect-claytondev.rhcloud.com/github/boekkooi/openshift-cartridge-php
```

## Versions
Currently this cartridge has the following versions:
- PHP 5.5.22
- PHP 5.6.16

If you need another version you can compile it yourself and submit a PR to get it integrated.

## Configuration
For the best result with this cartridge you are advised to create a `.openshift/action_hooks/build` and add the following to it:  
```BASH
#!/bin/bash
set -e

# Build PHP extra's
# Update conf/ini files and install pecl extensions
${OPENSHIFT_PHP_DIR}/bin/control build
```

Now it's time to configure nginx edit your `.openshift/nginx.conf.erb` and add the following within the `server` section:
```
# pass the PHP scripts to PHP-FPM
location ~ \.php$ {
    fastcgi_pass unix:<%= ENV['OPENSHIFT_PHP_SOCKET'] %>;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_script_name;
    include <%= ENV['OPENSHIFT_NGINX_DIR'] %>/usr/nginx-<%= ENV['OPENSHIFT_NGINX_VERSION'] %>/conf/fastcgi_params;
}
```

### PHP.ini etc.
If you have created `.openshift/action_hooks/build` you can fully customize the PHP configuration.
In your application create the following directories:
```
.openshift/cli/
.openshift/fpm/
```

In the `cli` directory create the `php.ini.erb` file and copy the content from [`conf/php.ini.erb`](https://github.com/boekkooi/openshift-cartridge-php/blob/master/conf/php.ini.erb) into it.
Now you can customize the cli php configuration.

In the `fpm` directory create the `php.ini.erb` file and copy the content from [`conf/php-fpm.ini.erb`](https://github.com/boekkooi/openshift-cartridge-php/blob/master/conf/php-fpm.ini.erb) into it.
Also create the `php-fpm.conf.erb` file and copy the content from [`conf/php-fpm.conf.erb`](https://github.com/boekkooi/openshift-cartridge-php/blob/master/conf/php-fpm.conf.erb) into it.
Now you can customize the php-fpm configuration.

## Composer/PEAR
Composer is installed by default and can be used by simply ssh to your application and typing in `composer`.

So where is PEAR? It's not there! Why? Read [The rise of Composer and the fall of PEAR](http://fabien.potencier.org/article/72/the-rise-of-composer-and-the-fall-of-pear).
If you really need PEAR then download it your self using [`php go-pear.phar`](http://pear.php.net/manual/en/installation.getting.php) and pray it work. *Any PR's related to PEAR or failure to install it will be ignored*

### PECL
If you have created `.openshift/action_hooks/build` you can create the `.openshift/php-pecl.txt` to auto install pecl extensions.
This file must constain have a pecl extension name and version per line for example:
```
apcu 4.0.7
mongo 1.6.5
```
Note for Openshift online: even though the scripts should automatically add the extension declaration in the php.ini files, if you have custom ini.erb files the extension declaration might be overwritten when they are deployed. In that case you must declare the extension manually in your .ini.erb files.

### Phalcon
There is special support for [phalcon](http://phalconphp.com/) you can simply install it by adding the following to your `.openshift/php-pecl.txt` file.
```
phalcon 1.3.4 --enable-phalcon
```
Don't forget to change your `.openshift/nginx.conf.erb` according to the [phalcon nginx installation notes](http://docs.phalconphp.com/en/latest/reference/nginx.html).

### Compiling a new version
To compile a new version you will first need a openshift application.
```BASH
rhc create-app nginx http://cartreflect-claytondev.rhcloud.com/github/boekkooi/openshift-cartridge-nginx
```

Now clone the repository and create a `php` folder. Now copy the `usr/compile` directory from [this](https://github.com/boekkooi/openshift-cartridge-php) repository.
Now set the versions you need to compile in the `php/compile/versions` file. Commit and push the application repository.

SSH into your app and go to the compile folder (`cd ${OPENSHIFT_REPO_DIR}/php/compile`) and start compiling by running the following commands:
```BASH
./libs
./php
./libs_package
```
Once compiling is done you can download the `php-{version}.tar.gz` from you application.
Extract the `php-{version}` from the archive and place them into the `openshift-cartridge-php/usr` folder.
Last but not least edit the `openshift-cartridge-php/manifest.yml` and add the versions.

All done just commit and push to your `openshift-cartridge-php` repo and use:
```BASH
rhc cartridge add -a myapp http://cartreflect-claytondev.rhcloud.com/github/<user>/openshift-cartridge-php
```

## Updates
Updating this cartridge is not as easy as I would like because openshift online won't allow updates for downloaded cartridges.
To update the cartridge you can do the following:
```BASH
rhc cartridge remove -a myapp --confirm  php
rhc cartridge add -a myapp http://cartreflect-claytondev.rhcloud.com/github/<user>/openshift-cartridge-php
```
This will remove the old version and install the latest version.
