# Cloud Haskell over ØMQ

[![Hackage package][Hackage Version Image]][Hackage package]
[![Build Status][Build Status Image]][Build Status]

[Hackage Version Image]: http://img.shields.io/hackage/v/network-transport-zeromq.svg
[Hackage package]: http://hackage.haskell.org/package/network-transport-zeromq
[Build Status Image]: https://secure.travis-ci.org/tweag/network-transport-zeromq.svg?branch=master
[Build Status]: http://travis-ci.org/tweag/network-transport-zeromq

[network-transport][network-transport] backend based on the
[ØMQ][zeromq] brokerless protocol. This implementation makes it
possible to access the wealth of ØMQ transports through a simple and
shared API. In particular, ØMQ supports authenticated communication
channels, encryption, efficient multicast and throughput enhancement
techniques such as message batching.

Wrapping a subset of the ØMQ API behind the network-transport API
makes it possible for a wealth of higher-level libraries such as
[distributed-process][distributed-process] and [HdpH][hdph] to
communicate over ØMQ seamlessly, with little to no modification
necessary.

[network-transport]: http://hackage.haskell.org/package/network-transport
[distributed-process]: http://hackage.haskell.org/package/distributed-process
[hdph]: http://hackage.haskell.org/package/hdph
[zeromq]: http://zeromq.org

Features
--------

### Plain text authorization

It's possible to add default user and password for all transport
connection by setting authorization ZMQParameters
```haskell
defaultZMQParameters{ authorizationType = ZMQAuthPlain "user" "password" }
```

### Reliable connections

n-t-zmq uses Push-Pull pattern to implement reliable connections.

### Multicast protocol

network-transport-zeromq provide multicast group based on Pub-Sub
protocol. This protocol is semi-reliable, in that if the high water
mark (HWM) is reached then some messages may be lost.

### Manual connection break

ØMQ automatically reconnects when connection is down and resend
messages so no message will be lost, however this may break some user
assumptions thus it's possible to mark.

Stability
---------

Experimental.

Currently all tests from
[network-transport-tests][network-transport-tests] are passing. All
tests from [distributed-process-tests][distributed-process-tests] are
also passing, except monitoring and connection failure tests.

[network-transport-tests]: http://hackage.haskell.org/package/network-transport-tests
[distributed-process-tests]: https://github.com/haskell-distributed/distributed-process-tests

Credits
-------

![Tweag I/O](http://i.imgur.com/0HK8X4y.png)

network-transport-zeromq is maintained and funded by [Tweag
I/O](http://tweag.io/).

The names and logos for Tweag I/O are trademarks of EURL Tweag.

Got questions? Need help? Tweet at [@tweagio](http://twitter.com/tweagio).

License
-------

network-transport-zeromq is Copyright © 2014 EURL Tweag. It is free
software, and may be redistributed under the terms specified in the
LICENSE file.
