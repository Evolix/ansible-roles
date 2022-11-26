# respect Cache-Control from client
if (req.http.Cache-Control ~ "(private|no-cache|no-store)" || req.http.Pragma == "no-cache") {
    return (pass);
}
