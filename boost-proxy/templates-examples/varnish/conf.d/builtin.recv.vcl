if (req.method == "PRI") {
    /* This will never happen in properly formed traffic (see: RFC7540) */
    return (synth(405));
}
if (!req.http.host &&
    req.esi_level == 0 &&
    req.proto ~ "^(?i)HTTP/1.1") {
    /* In HTTP/1.1, Host is required. */
    return (synth(400));
}
if (req.method != "GET" &&
    req.method != "HEAD" &&
    req.method != "PUT" &&
    req.method != "POST" &&
    req.method != "TRACE" &&
    req.method != "OPTIONS" &&
    req.method != "DELETE" &&
    req.method != "PATCH") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
}
if (req.method != "GET" && req.method != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
}
if (req.http.Authorization || req.http.Cookie) {
    /* Not cacheable by default */
    return (pass);
}
