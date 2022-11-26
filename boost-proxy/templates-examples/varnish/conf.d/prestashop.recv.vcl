## From https://github.com/CleverCloud/varnish-examples/blob/master/prestashop.vcl

# Normalize the header, remove the port (in case you're testing this on various TCP ports)
set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
# Remove has_js and CloudFlare/Google Analytics __* cookies.
set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
# Remove a ";" prefix, if present.
set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
# Allow purging from ACL
if (req.method == "PURGE") {
    # If not allowed then a error 405 is returned
    if (client.ip != "127.0.0.1" ) {
        return (synth(405, "This IP is not allowed to send PURGE requests."));
    }
    # If allowed, do a cache_lookup -> vlc_hit() or vlc_miss()
    return (purge);
}
# Post requests will not be cached
if (req.http.Authorization || req.method == "POST") {
    return (pass);
}
if (req.method == "GET" && (req.url ~ "^/?mylogout=")) {
    unset req.http.Cookie;
    return (pass);
}
#we should not cache any page for Prestashop backend
if (req.method == "GET" && (req.url ~ "^/admin70")) {
    return (pass);
}
#we should not cache any page for customers
if (req.method == "GET" && (req.url ~ "^/authentification" || req.url ~ "^/my-account")) {
    return (pass);
}
#we should not cache any page for customers
if (req.method == "GET" && (req.url ~ "^/identity" || req.url ~ "^/my-account.php")) {
    return (pass);
}
#we should not cache any page for sales
if (req.method == "GET" && (req.url ~ "^/cart.php" || req.url ~ "^/order.php")) {
    return (pass);
}
#we should not cache any page for sales
if (req.method == "GET" && (req.url ~ "^/addresses.php" || req.url ~ "^/order-detail.php")) {
    return (pass);
}
#we should not cache any page for sales
if (req.method == "GET" && (req.url ~ "^/order-confirmation.php" || req.url ~ "^/order-return.php")) {
    return (pass);
}
if (req.method != "GET" && req.method != "HEAD") {
    return (pass);
}
# Remove the "has_js" cookie
set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");
# Remove any Google Analytics based cookies
# set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
# removes all cookies named __utm? (utma, utmb...) - tracking thing
set req.http.Cookie = regsuball(req.http.Cookie, "(^|(?<=; )) *__utm.=[^;]+;? *", "\1");
# Remove a ";" prefix, if present.
set req.http.Cookie = regsub(req.http.Cookie, "^;\s*", "");
# Are there cookies left with only spaces or that are empty?
if (req.http.Cookie ~ "^ *$") {
  unset req.http.Cookie;
}
# Cache the following files extensions
if (req.url ~ "\.(css|js|png|gif|jp(e)?g|swf|ico|woff)") {
    unset req.http.Cookie;
}
# Normalize Accept-Encoding header and compression
# https://www.varnish-cache.org/docs/3.0/tutorial/vary.html
if (req.http.Accept-Encoding) {
    # Do no compress compressed files...
    if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
        unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
        set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
        set req.http.Accept-Encoding = "deflate";
    } else {
        unset req.http.Accept-Encoding;
    }
}
# Did not cache HTTP authentication and HTTP Cookie
if (req.http.Authorization) {
    # Not cacheable by default
    return (pass);
}
