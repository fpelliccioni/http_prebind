Usefulness:
=====================================
From the original author:


This is a sloppy hack to speed up BOSH session initiation for logged-in users.

The web server makes a single GET request to start the session and passes the JID, SID, and RID in the HTML for Strophe::attach().

I created http_prebind because

* user passwords are not known because they are stored hashed, and
* the BOSH handshake is too complex.

This module allows a predefined system user to create sessions for other users without knowing their passwords.
It speeds up the process of getting the authenticated user connected over BOSH.
It could be more secure and easier to set up and use but I stopped working on it when it met my needs. I will be happy to see it forked and improved or made obsolete.


Installation:
=======================================

* You will need to ensure whatever auth module you use in ejabberd to accept a
  common shared password.

* Run rake configure

* Edit src/http_prebind.erl and replace these:

  * EJABBERD_DOMAIN => Your preferred service domain (e.g. chat.yoursite.com)
  *       AUTH_USER => The user you plan to use in your Http Basic Auth
  *   AUTH_PASSWORD => The password you'll use in your auth - both http basic
      and auth module (the auth module must accept this password for each user)

* Run rake build

* If it's been successful, then run rake install

* Add this to your ejabberd.cfg in the http_fileserver section:
   {["http-prebind"], http_prebind},

* Restart ejabberd or Reload the configuration from the debug console:
    ```ejabberd_config:load_file("/etc/ejabberd/ejabberd.cfg")```.

```
Sample HTTP request: (username is andy)
GET /http-prebind/andy HTTP/1.0
Host: im.wordpress.com
Authorization: Basic my_precomputed_systemuser_auth


Sample HTTP response: (the body is JID\nSID\nRID)
HTTP/1.0 201 Created
Connection: close
Content-Type: text/html; charset=utf-8
Content-Length: 99

andy@im.wordpress.com/19470701321248704284877554
938f2ae10569c24367c0822e76e42dd5cd026f71
461602958

```
