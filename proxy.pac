//  -*- mode: javascript; -*-
// Proxy functions set three ports; 8157 for AWS, 8158 for Google, 8159 for Azure
function FindProxyForURL(url, host) {
    // special rule for *.xip.io, used with CDSW - edit proxy port per cloud platform
    if (shExpMatch(host, "*.xip.io") || shExpMatch(host, "*.nip.io"))  {
        return "SOCKS5 localhost:8158";
    }

    // match AWS internal DNS
    if (shExpMatch(host, "ip-*.internal")) {
        return "SOCKS5 localhost:8157";
    }
    
    // match GCP internal DNS
    // edit for your project id as part of the match, e.g.  "*.c.my-gcp-proj.internal"
    if (shExpMatch(host, "*c.gcp-se.internal")) {
        return "SOCKS5 localhost:8158";
    }

    // match Azure compute URLs
    if (shExpMatch(host, "*.cdh-cluster.internal") || shExpMatch(host, "*.cloudera-magic.internal") || shExpMatch(host, "*.gg-cluster.internal") ) {
        return "SOCKS5 localhost:8159";
    }

    // match CDSW wildcard DNS - edit proxy port per cloud platform
    if (shExpMatch(host, "*cdsw.internal") ) {
        return "SOCKS5 localhost:8159";
    }

    // All other requests go direct, not through the proxy
    return "DIRECT";
}
