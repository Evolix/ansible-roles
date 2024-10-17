# ssl

Deploy SSL certificate, key, dhparams and concatenate them when needed (eg. with HAProxy).

## Available variables

* `ssl_cert`: name of SSL certificate which is going to be deployed

eg. `ssl_cert: "example.com"` deploy files/ssl/example.com.{pem|key|dhp}
