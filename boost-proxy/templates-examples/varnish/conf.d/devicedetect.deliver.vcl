# to keep any caches in the wild from serving wrong content to client #2
# behind them, we need to transform the Vary on the way out.
if ((req.http.X-UA-Device) && (resp.http.Vary)) {
    set resp.http.Vary = regsub(resp.http.Vary, "X-UA-Device", "User-Agent");
}
