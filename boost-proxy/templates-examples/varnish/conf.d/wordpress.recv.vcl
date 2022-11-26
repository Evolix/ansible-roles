if (req.url ~ "^/wp-(login|admin)" || req.url ~ "preview=true" || req.http.Cookie ~ "wordpress_logged_in_" ) {
    return (pass);
}
