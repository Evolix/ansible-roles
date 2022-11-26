
# so, this is a bit counterintuitive. The backend creates content based on
# the normalized User-Agent, but we use Vary on X-UA-Device so Varnish will
# use the same cached object for all U-As that map to the same X-UA-Device.
#
# If the backend does not mention in Vary that it has crafted special
# content based on the User-Agent (==X-UA-Device), add it.
# If your backend does set Vary: User-Agent, you may have to remove that here.
if (bereq.http.X-UA-Device) {
    if (!beresp.http.Vary) { # no Vary at all
        set beresp.http.Vary = "X-UA-Device";
    } elseif (beresp.http.Vary !~ "X-UA-Device") { # add to existing Vary
        set beresp.http.Vary = beresp.http.Vary + ", X-UA-Device";
    }
}
# comment this out if you don't want the client to know your
# classification
set beresp.http.X-UA-Device = bereq.http.X-UA-Device;
