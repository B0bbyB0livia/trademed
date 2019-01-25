# Install

The same code is used on both the market and payment server, with configuration options used to distinguish these two roles.

The payment server is optional.
You may prefer to use another wallet software to generate a bitcoin payment address set then write your own script to upload the addresses to the market server API.

Another option is to setup the payment server to generate and upload the initial address set, then it could be powered off for extra security.
Refund payments could then be processed manually using funds from another wallet, with the payment server only powered on occasionally to access funds to send to other wallets.
The market administration web interface has a form to manually mark payments as paid. Normally this would be done automatically by the payment server connecting to market API.

A multi-vendor setup is not discussed here since most installs would likely be for a single vendor.
It is much the same but with some additional settings like ENABLE_VENDOR_REGISTRATION_FORM, COMMISSION. All the code is provided to run a multi-vendor setup.


## Requirements

The requirements for both servers are:

* Linux
* docker
* docker-compose
* bitcoind >= 0.15
* git

A full blockchain on disk is not necessary because pruning can be enabled meaning that disk space requirements are only about 3-4 GB.

Earlier versions of bitcoin should work except for when processing payments because the sendmany RPC call has an additional argument that was added in 0.15.
bitcoind 0.16 is recommended to take advantage of segwit payment addresses.

TOR proxies should be available to both servers in the recommended setup but this is not necessary.
For this example, TOR will be used to host the market HTTP service (hidden service). The payment server will need access to a TOR proxy so it can contact the market server API.

A system to generate a PGP key or an existing PGP key is needed.
It will be imported into the docker images of the market and payment server applications and when they are built by docker.
On the market server it will only be used for displaying to users.
On the payment server the private key will be imported (during image build) so that bitcoin address strings can be clearsigned.

In this example bitcoind will not run as a docker instance.


## Common setup

On both servers, install the required software.

Add two new user accounts to run bitcoind and the rails application. In this example they will be named *btc* and *rails* but any names can be used.
The objective is to have bitcoind running under a different user account to the rails application for security reasons.

Configure .bitcoin/bitcoin.conf and start the daemons on both servers.

```
# Allow connections from docker instances. This should be the network range that docker uses.
rpcallowip=172.17.0.0/16
# Optional pruning to save space.
prune=1000

# Not required but should be enabled on payment server to allow retransmission with higher fees.
walletrbf=1

# Optional extra security for payment server bitcoind which holds private keys. The first IP is the docker gateway IP (ifconfig will show it).
bind=172.17.0.1
bind=127.0.0.1
rpcbind=172.17.0.1
rpcbind=127.0.0.1
```

The market bitcoind doesn't need a passphrase on the wallet file because no private keys will exist.
You may have a passphrase on the payment server wallet file but the application expects the wallet
to be unlocked when it tries to use the RPC for generating addresses or making payments.

Use a system monitoring application like Nagios to ensure bitcoind is running and to start bitcoind if it isn't running.
Without bitcoind running, the market server will not be able update orders to paid status.


Create a directory as the rails user to hold docker persistent volume mounts. These are to allow logs and images to be saved persistently.
In this example we use /home/rails/docker/ but you can use any directory name.
The log and public/system directory will be written to by the user ID inside the docker instance (should be ID 1000).

```
mkdir -p /home/rails/docker/{log,public/system}
chmod 777 /home/rails/docker/*
```

Install the source code from GitHub:

```
cd /home/rails/docker
git clone https://github.com/kimdotonion/trademed.git
```


## Market server setup

The application is configured with environment variables which allows altering settings without changing any files. The variable names are all capitalized.
The list of all configuration settings are in config/application.rb.

Some of these settings have different meanings depending on the context of market server or payment server.

When starting the application using docker, the configuration environment variables can be stored in a separate file and used with `docker run --env-file` option.
In this example, docker-compose is used and the environment variables are set in the docker-compose.yml file.

There are various features that are only applicable to a multi-vendor setup such as displaying a vendor network withdrawal fee in the navigation bar for vendors.
These can be ignored in a single vendor setup and the code could be deleted for simplified views.

### TOR hidden service

Configure TOR to host a hidden service. It is recommended that the hidden service is reverse proxied though apache / nginx or similar.
Using a reverse proxy is not necessary but allows more control of adding/removing HTTP headers and other security features.
The reverse proxy may be configured to add this Content Security Policy header which can help protect users if they have forgotten to disable javascript.

```
Content-Security-Policy "default-src 'self'; script-src 'none'; frame-ancestors 'none'; "
```

The rails application will listen on http://localhost:3000/.
If you don't want to configure a reverse proxy, simply configure the TOR hidden service to connect requests to localhost:3000.

For this setup example the hidden service name is kkgkibeukrz2vuf2.onion.



### Build the docker image for market server

Create gpgkeyimport.txt in the trademed directory. This must contain an export of the **public** GPG key.
The application will display the public key during the user signup process. The corresponding private key will be used to sign all payment address strings on payment server.

Copy your own logo graphic file to trademed/app/assets/images/. It can be named anything but the default name is trademed.png unless configured otherwise using LOGO_FILENAME.
It is recommended to name it logo.png and set LOGO_FILENAME=logo.png because git will ignore that file which makes application updates easier.
Width should be approximately 260px. 

A background banner image can optionally be displayed across top of page - edit bottom of application_layout.css.scss for this.

Build the docker image.

```
docker build -t trademed /home/rails/docker/trademed/
```


### Configuration settings

All config settings are in config/application.rb and most of them are set from environment variables. Read through that file for more documentation on the settings.

Create /home/rails/docker/docker-compose.yml using the example provided and configure the following settings.

If you are not using /home/rails/docker/ location, then ensure volumes setting in docker-compose.yml is correct.

Delete settings *PAYOUT_BITCOIND_URI, TOR_PROXY_HOST, TOR_PROXY_PORT, ADMIN_API_URI_BASE*. These are only applicable to the payment server.

`POSTGRES_PASSWORD` -
Used by the Postgresql image to set database admin password. This is not a trademed setting and is not used by trademed.
It is possible to omit this setting and the database will be brought up without an admin password, then any process on the machine could access the database in the container.
Therefore it is a good idea to set an admin password.

`DATABASE_URL` -
This is used by the application to store the database name and credentials. Choose a password and configure it in this setting.
The database name, username, hostname do not need changing from the default values since the database will run as a docker container so there will be no naming conflict.

`ADMIN_HOSTNAME` -
To secure the admin section of the website, the ADMIN_HOSTNAME setting is used to restrict access based on the Host header of the request.
If the Host header in the request does not match ADMIN_HOSTNAME when accessing the admin sections of the website, then the request is denied by the web application.
You may setup a second TOR hidden service hostname dedicated to administration access or make ADMIN_HOSTNAME a subdomain of your existing hidden service,
ie secretadmin.kkgkibeukrz2vuf2.onion.

Basically, a different hostname should be used by the administrator for security reasons and the admin hostname should remain secret.
If you don't require this additional security, set ADMIN_HOSTNAME to your public hidden service hostname.


`SECRET_KEY_BASE` -
Standard rails setting for a secret, typically a 128 hex char string. If you have an existing rails installation use `rake secret` to generate one.
This should be different to the one on payment server.


`LOGO_FILENAME` -
The name of the graphic file you copied to trademed/app/assets/images.


`MARKET_BITCOIND_URI` -
Location and credentials to access bitcoind RPC. If using litecoin, then set MARKET_LITECOIND_URI as well.


`GPG_KEY_ID ` -
The key ID of the key inside gpgkeyimport.txt.


`ADMIN_API_KEY ` -
Generate another secret (ie 128 hex char string). This is basically a long password that clients must provide to use the API.


`BLOCKCHAIN_CONFIRMATIONS` -
On the market server this determines how many bitcoin confirmations are necessary on order payments before the order status becomes paid. It may be set to 0.


`DISPLAYNAME_HASH_SALT` -
Set this to a random string. It is used to hash buyer names when displaying feedback.


`CURRENCIES` -
Optionally set the list of currencies that users may choose from. Once set, it is best not to remove any from the list but more can be added later. See config file for the default list.

`BITCOIND_WATCH_ADDRESS_LABEL` -
See config/application.rb for settings BITCOIND_ORDER_ADDRESS_LABEL, BITCOIND_WATCH_ADDRESS_LABEL.
Optional default empty string.
Imported addresses (watch addresses) can be assigned a name or left un-named.
If using bitcoind < 0.17 then addresses are named using accounts rather than labels and it is preferable to use the default account named ''.
But if using bitcoind < 0.17 and you want to use an account to name watch addresses on the market server, manually create that account before proceeding because bitcoind requires it to exist before imported addresses use the account name.

`ENABLE_VENDOR_REGISTRATION_FORM` -
On the user registration form, show two fields for registering a vendor account. Leave this disabled for a single vendor site.
Optional, default false if omitted.

`ENABLE_MANDATORY_PGP_USER_ACCOUNTS` -
This option will require new accounts to have a PGP public key saved. It will also change the user registration form to have a PGP field.
Optional, default false if omitted.

`ENABLE_SUPPORT_TICKETS` -
Optional, default no. This will display a support link in the navigation bar to a basic ticketing system.
Admin users can only communicate with buyers and vendors using tickets. Admin users can't use messaging.
Enable this when running a multi-vendor site.


### Initial starting the application (market)

Verify the docker-compose.yml file using ```docker-compose config``` with the working directory being where the file is stored.

Run `docker-compose up` in the same directory containing the docker-compose.yml file. This will start two docker instances - the application and the database instance.


#### Setup the database

Find the IP of the database instance and connect with psql. Use `docker ps` and `docker inspect CONTAINERID` to find the database containers IP.
psql will prompt for password if you set one in POSTGRES_PASSWORD.

```
docker run -it --rm postgres psql -h 172.17.0.2 -U postgres
```

To avoid looking up the IP address of the database instance, use the link option to docker run. Example:

```
docker run -it --rm --link trademed_db_1:db_host postgres psql -h db_host -U postgres
```

Once connected with psql, create a database user and give it the password from DATABASE_URL. If you are running multiple instances of trademed, the role name can be the same
because each instance uses a separate database container but make passwords different for better security. The superuser privilege is needed for the role to initially create tables but could be removed after.

```
CREATE ROLE trademed_prod WITH SUPERUSER LOGIN PASSWORD 'aaaccceee' ;
```

Exit psql and now setup the database tables and populate initial data.

```
docker-compose run --rm trademed rake db:setup
```

If this setup is restoring from backup, use psql in the database image to load the data. The backup file should be data only.

```
docker run --rm -i postgres:latest psql -h 172.17.0.2 -U postgres trademed_production  < backup.sql
```

### Create a vendor account

You should now be able to use a web browser to access the web service listening on port 3000 of the market server.
If a web page with your logo is rendered then the database and application setup was successful.

Use the Register button to create a new buyer or vendor account. Only vendor accounts can list products and only buyer accounts (the default type) can buy products.

To make a vendor account, a unique code needs to be provided on the registration form.
Rather than describing how to create the unique code, it is easier to register the account with vendor option unchecked and use the admin web interface described below to change the account type to vendor.
In the admin web interface, click Users, then the user, check Vendor option, Submit.

It should be possible to begin listing products for sale with the vendor account but before that, login as admin and create the product categories and locations.


### Create an admin account

Admin accounts can have any username and do not conflict with buyer/vendor account names.
There are currently no web forms for managing admin accounts so any new accounts or changes to admin accounts need to be done on the console.
Use the rails console to create an admin account using the example below and make your own values for these fields. Currency should be one of the codes from the CURRENCIES config option.
Timezone should be one of the keys from this [mapping](https://api.rubyonrails.org/classes/ActiveSupport/TimeZone.html).

```
docker-compose run --rm trademed rails console

AdminUser.create!(username: 'admin', displayname: 'Admin', password: 'adminpass', password_confirmation: 'adminpass', timezone: 'UTC', currency: 'USD')
```

To login as an admin, first logout if you are logged in as a standard user.

Browse to /admin/sessions/new to login. Remember to use ADMIN_HOSTNAME to access this.


### Product categories

After logging in as admin, click Categories in the nav menu to setup product categories.

### Locations

After logging in as admin, click Locations in the nav menu to setup locations used for defining product shipping origins and destinations.


### Schedule blockchain checking job


New order payments are verified by `app/jobs/update_orders_from_blockchain_job.rb`. This process will change order status to paid.
This job should be scheduled to run every 5-10 minutes using an external scheduler such as crond.
Take steps to ensure multiple processes of this job never run simultaneously.
If using cron then something like flock should be used so cron doesn't start another process while an older process has not finished.

Example:

```
docker-compose run --rm trademed rails r 'UpdateOrdersFromBlockchainJob.perform_now'
```

[An example is provided](examples/update_orders_from_blockchain_job.sh).


### Schedule exchange rate updates

If you are running litecoind and want to accept litecoin payments, then create a litecoin payment method in the database.
Vendors specify which payment methods each product will accept. By default the only payment method is bitcoin.

```
docker-compose run --rm trademed rails r  "PaymentMethod.create( name: 'Litecoin', code: 'LTC' )"
```

There are three different jobs that update exchange rates from different sources. Bitcoin exchange rates can be updated from Blockchain.info and Bitpay.com.
Choose from one of the two for updating bitcoin exchange rates. Litecoin exchange rates are updated from Coinmarketcap.com.

```
docker-compose run --rm trademed rails r 'BtcRatesBlockchaininfoJob.perform_now'
docker-compose run --rm trademed rails r 'BtcRatesBitpayJob.perform_now'

docker-compose run --rm trademed rails r 'LtcRatesCoinmarketcapJob.perform_now'
```

### Schedule finalizing shipped orders

The auto finalize job changes the state of shipped orders to finalized after a specific duration. Normally the buyer would finalize the order to indicate sale successfully completed
but if they do not then this job will finalize the order. When order is finalized it is no longer eligible for buyer refunds.

```
docker-compose run --rm trademed rails r 'AutofinalizeJob.perform_now'
```

## Payment server setup

The payment server only uses TOR to connect to the market server. You can also configure bitcoind to use TOR to help anonymize transactions broadcast.
The payment server should be isolated from the market server. This way if the market server is compromised, no information will reveal the payment server location.

Build the docker image using the same steps as for the market server, except the gpgkeyimport.txt will need to contain the private key as well without a passphrase.
Export the secret key and write text to gpgkeyimport.txt in the trademed directory.

```
gpg --export-secret-keys -a KEYID
```

This key will be used to clearsign bitcoin address strings.
Inside the docker image it will be imported to the keyring of the application user id and the application expects to use it without a passphrase.

When building the image, check the output to ensure import successful - `gpg: secret keys imported: 1`.

Create /home/rails/docker/docker-compose.yml using the example file in the source code and configure the following settings.


### Configuration settings


`POSTGRES_PASSWORD` -
Same as above.

`SECRET_KEY_BASE` -
Same description as above but it should be different to the one on market server.


`GPG_KEY_ID ` -
The key ID of the key inside gpgkeyimport.txt.


`PAYOUT_BITCOIND_URI` -
Location and credentials to access RPC of bitcoind which holds the private bitcoin keys. If using litecoin, then set PAYOUT_LITECOIND_URI as well.
If bitcoind is on the same host as the application but not in a docker container, you can specify the IP of the docker gateway network interface.

`BITCOIND_ORDER_ADDRESS_LABEL` -
When payment addresses are generated they are assigned to this label (or account in bitcoind < 0.17).
If you are running multiple instances of the app with one bitcoind process then you could use this to associate generated addresses to what application created them.

`TOR_PROXY_HOST` -
The IP address of the host running a TOR proxy. This could be localhost if TOR daemon running locally.
When processes on the payment server communicate with the market HTTP API they use TOR when this setting is configured.
If this is unset then the processes will connect directly without TOR.


`TOR_PROXY_PORT ` -
The TCP port TOR listens on.


`ADMIN_API_KEY` -
The same ADMIN_API_KEY as configured on market server. This will be presented in API calls to the market server so the market server can authenticate the request.

`ADMIN_API_URI_BASE` -
The URI to the market server without the path name. ie http://secretadmin.kkgkibeukrz2vuf2.onion
This will be the same as the market server ADMIN_HOSTNAME setting but prefixed with http://


`BLOCKCHAIN_CONFIRMATIONS` -
The number of confirmations received funds must have before they can be spent in transactions generated by the payment server.
You will want this to be at least 3, regardless of what this setting is on the market server.



### Initial starting the application (payment server)

Run `docker-compose up` in the directory containing the docker-compose.yml file. This will start docker instances for the application and database.
The database instance will print the initial database setup the postgres image goes through first time.

Next time you won't need to see all the output so use `docker-compose start` instead.

Use the same instructions above for setting up the postgres database (psql, rake db:setup). Then create an admin user on the console.

Unlock the payment server bitcoind wallet if it is passphrase protected.

If you want to create litecoin addresses, make a litecoin payment method as described above.

Run the generate_address.rb script with --test parameter. It won't make any changes to the wallet or database and tests connectivity only.
For litecoin tests and address creation, use --address-type LTC

```
rails r generate_address.rb --verbose --test --address-type BTC
```

[Example screenshot generate test](examples/Screenshot_generate_address_test.png)

Next try generating a single address. Once that works you can generate hundreds or thousands more by specifying how many with count parameter.

```
docker-compose run --rm trademed rails r generate_address.rb --verbose --count 1 --address-type BTC
```

[Example screenshot generate](examples/Screenshot_generate_address.png)

Verify that the address exists inside the wallet by using `bitcoin-cli getaddressesbylabel`, or `getaddressesbyaccount` on older versions.

Then login to the payment server admin web page and click "Generated addresses" to verify it was saved to the application database. The address count shown should be correct.
Logs of addresses created are saved to log/script.log.



Next, the generated addresses need uploading to the market server.
If the market server is using TOR hidden services, before doing the upload, verify that your TOR proxy is available and the market hidden service can be reached. Use the settings
TOR_PROXY_HOST, TOR_PROXY_PORT and ADMIN_API_URI_BASE in the curl request to check connectivity.

```
curl --socks4a localhost:9050 https://check.torproject.org
curl --socks4a localhost:9050 http://kkgkibeukrz2vuf2.onion/
```

If the market is not using TOR, ensure the environment setting TOR_PROXY_HOST is not set and the script will connect directly without TOR.

Ensure that bitcoind is running on the market web server so that uploaded bitcoin addresses can be imported. Note, only bitcoin public keys are uploaded.
If litecoin addresses were generated, ensure litecoind running on the market server. If uploading litecoin addresses then market server needs to have
the litecoin payment method defined in its database (by default it is).
The upload_to_market.rb script has an option to restrict what type of addresses are uploaded (ie btc only).
If the address type is not defined then all addresses in the database are uploaded.

```
docker-compose run --rm trademed rails r upload_to_market.rb -- --verbose --btc
```

[Example screenshot upload](examples/Screenshot_upload_to_market.png)

Each generated address is uploaded in a separate request. If the script fails part way though it is likely that your TOR circuit was dropped.
In that case run the script again and it will continue where it left off.

On the market server, click "Market addresses" to see if the upload worked and how many are now available.
The number of generated addresses on the payment server should be equal to the number of market addresses available.

[Example screenshot admin market addresses](examples/Screenshot_admin_market_addresses.png).

If the upload worked, you should then verify addresses imported to bitcoind on the market server.
This script will check that all the bitcoin payment addresses on the market server database have been added as watch addresses in the bitcoind wallet.
It generates RuntimeError exception when the wallet does not have all the addresses. So if no error displayed then upload to market was successful.
It also will check litecoin addresses if that payment method exists on market server.
Run this command on the **market server**:

```
docker-compose run --rm trademed rails r check_bitcoind_watches_setup.rb
```

[Example screenshot check watches](examples/Screenshot_check_watches_setup.png).

They can also be checked manually using `bitcoin-cli getaddressesbylabel`, or `getaddressesbyaccount`.


Now the market server is ready to assign bitcoin addresses to new orders.

Bitcoind on the payment server only needs to be available for generating new addresses and processing payments.
Payments information can be retrieved from the market by either of these two methods below. The data is retrieved over TOR using the API.
Payments are either refunds to buyers or payments to vendors. Payments to vendors would usually only occur in a multi-vendor setup.
Another wallet could manually make payments instead and the market could be manually updated through the admin interface to show payments as completed.

Method 1:

```
docker-compose run --rm trademed rails r 'ImportOrderPayoutsJob.perform_now'
```
Method 2:

```
docker-compose run --rm trademed rails r 'ProcessPayoutsJob.perform_now(import:1, dry_run:1)'
```

Once payment information is saved to the payment server database, payments can be generated by running this job. It has many options, read app/jobs/process_payouts_job.rb for details.

```
docker-compose run --rm trademed rails r 'ProcessPayoutsJob.perform_now()'
```

It will generate a single bitcoin transaction containing all payments owing and broadcast it. Then it will connect back to the market to update the market records.


# Upgrades

Rebuild the docker image the same way as described.
Stop the old instances with `docker-compose stop`.
Recreate new container for app and start it using `docker-compose up`.

If any database migration files exist in the newly built image, the database will need migrations to be applied. The web service should still work when migrations have not
been applied but if any code tries to use new database fields that do not yet exist, then an error occurs in the app.
Run `docker-compose run --rm trademed rake db:migrate`. This updates the database and the existing containers started from the new image can remain running.

Assets are compiled during container build so there is no need to build asset pipeline.
