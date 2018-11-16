//  -*- mode: javascript; -*-
function FindProxyForURL(url, host) {
    // special rule for *.xip.io, used with CDSW - change to correct proxy port
    if (shExpMatch(host, "*.xip.io") || shExpMatch(host, "*.nip.io"))  {
        return "SOCKS5 localhost:8158";
    }
    // match Azure compute URLs
    if (shExpMatch(host, "*.cdh-cluster.internal") || shExpMatch(host, "*.cloudera-magic.internal") || shExpMatch(host, "*.gg-cluster.internal") ) {
        return "SOCKS5 localhost:8159";
    }

    // match CDSW wildcard DNS
    if (shExpMatch(host, "*cdsw.internal") ) {
        return "SOCKS5 localhost:8159";
    }

    // All other requests go direct, not through the proxy
    return "DIRECT";
}
