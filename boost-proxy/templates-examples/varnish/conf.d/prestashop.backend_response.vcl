## From https://github.com/CleverCloud/varnish-examples/blob/master/prestashop.vcl

# Remove some headers we never want to see
unset beresp.http.Server;
unset beresp.http.X-Powered-By;
# For static content strip all backend cookies
if (bereq.url ~ "\.(css|js|png|gif|jp(e?)g)|swf|ico|woff") {
    unset beresp.http.cookie;
}
# Don't store backend
if (bereq.url ~ "admin70" || bereq.url ~ "preview=true") {
    set beresp.uncacheable = true;
    set beresp.ttl = 30s;

    return (deliver);
}
if (bereq.method == "GET" && (bereq.url ~ "^/?mylogout=")) {
    set beresp.ttl = 0s;
    unset beresp.http.Set-Cookie;
    set beresp.uncacheable = true;

    return (deliver);
}
# don't cache response to posted requests or those with basic auth
if ( bereq.method == "POST" || bereq.http.Authorization ) {
    set beresp.uncacheable = true;
    set beresp.ttl = 120s;

    return (deliver);
}
    # don't cache search results
if ( bereq.url ~ "\?s=" ){
    set beresp.uncacheable = true;
    set beresp.ttl = 120s;

    return (deliver);
}
# only cache status ok
if ( beresp.status != 200 ) {
    set beresp.uncacheable = true;
    set beresp.ttl = 120s;

    return (deliver);
}
# A TTL of 2h
set beresp.ttl = 2h;
# Define the default grace period to serve cached content
set beresp.grace = 30s;