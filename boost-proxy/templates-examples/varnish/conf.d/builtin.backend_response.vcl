if (bereq.uncacheable) {
    return (deliver);
} else if (beresp.ttl <= 0s ||
    beresp.http.Set-Cookie ||
    beresp.http.Surrogate-control ~ "no-store" ||
    (!beresp.http.Surrogate-Control &&
        beresp.http.Cache-Control ~ "no-cache|no-store|private") ||
    beresp.http.Vary == "*") {
        # Mark as "Hit-For-Miss" for the next 2 minutes
        set beresp.ttl = 120s;
        set beresp.uncacheable = true;
}
