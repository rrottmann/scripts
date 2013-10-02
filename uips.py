#!/usr/bin/env python
"""
This script checks whether DNS entries for ips in the given subnet could be removed from DNS.
Copyright 2013 by Reiner Rottmann (reiner@rottmann.it). Released under the BSD license.
"""

import os
import sys
import socket
import logging

from optparse import OptionParser

logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.DEBUG)

class Host(object):
    """Host class"""
    def __init__(self, ip):
        self.ip=ip
        """The ip of the host."""
        try:
            self.hostname=socket.gethostbyaddr(self.ip)[0]
            logging.debug('RDNS of IP '+ self.ip + ' is '+self.hostname)
            """The hostname of the host."""
        except socket.herror:
            logging.error('Could not find host in DNS.')
            self.hostname=None
    def pingable(self):
        """Checks whether the host is pingable. Returns true or false."""
        ret=os.system("/bin/ping -q -c1 -i0.2 -W1 %s >/dev/null 2>&1" % (self.hostname))
        logging.debug("Ping return code: "+str(ret))
        if ret == 0:
            return True
        else:
            return False

def main():
    """ The main function."""
    parser=OptionParser()
    parser.add_option('-s', '--subnet', dest='subnet', help='The subnet to process. The last octett will be probed from 0-254. Default: 172.30.226.0', default='172.30.226.0')
    (options, args) = parser.parse_args()
    if not options.subnet:
        parser.print_help()
        sys.exit(0)
    hosts_to_delete=[]
    for i in xrange(1, 254):
        ip='.'.join(options.subnet.split('.')[0:-1]+[str(i)])
        logging.debug('Checking host with ip ' + ip)
        h=Host(ip=ip)
        if not h.hostname:
            logging.debug('Skipping host as it has no DNS record.')
            continue
        if h.pingable():
            logging.debug('Host is alive. Skipping it.')
        else:
            logging.info('Host does not respond. Marking host for deletion.')
            hosts_to_delete.append((h.ip, h.hostname))
    logging.info('Found the following hosts that could be removed from DNS:')
    for ip, host in hosts_to_delete:
        print ip, host

if __name__== "__main__":
    main()
