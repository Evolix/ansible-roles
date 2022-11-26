if (bereq.url ~ "wp-(login|admin)" || bereq.url ~ "preview=true" ||  bereq.http.Cookie ~ "wordpress_logged_in_" ) {
    set beresp.uncacheable = true;
    set beresp.ttl = 0s;
}
