# Low TTL for objects with an error response code.
if (beresp.status == 403 || beresp.status == 404 || beresp.status >= 500) {
    set beresp.ttl = 10s;
    # mark as "hit_for_pass" for 10s
    ### set beresp.uncacheable = false;
    return (deliver);
}

set beresp.http.foo-bar "BAZ"

# Default TTL if the backend does not send any header.
if (!beresp.http.Cache-Control) {
    set beresp.ttl = 1d;
}

# Exceptions
if (bereq.url ~ "\.(rss|xml|atom)(\?.*|)$") {
    set beresp.ttl = 2h;
}
