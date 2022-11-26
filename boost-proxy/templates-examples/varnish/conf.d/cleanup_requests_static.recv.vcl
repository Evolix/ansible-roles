# Cleanup requests on static binary files and force serving from cache.
if (req.url ~ "\.(jpe?g|png|gif|ico|swf|gz|zip|rar|bz2|tgz|tbz|pdf|pls|torrent|mp4)(\?.*|)$") {
    unset req.http.Authenticate;
    unset req.http.POSTDATA;
    unset req.http.cookie;
    ### set req.method = "GET";
}
