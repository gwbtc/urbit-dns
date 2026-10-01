::  dns-address: get a groundwire.me domain and install it
::
::    a groundwire fork of the upstream thread. we ask the sponsor's
::    %gw-dns to bind our address, hear back which domain it assigned
::    us, as a turf like /me/groundwire/kazoo/bespoke, and hand that
::    turf to eyre, which orders the certificate through %acme.
::    produces the turf
::
::    the upstream thread fetched its own address on port 80 through
::    iris before asking, and fetched the new domain the same way
::    before installing it.  neither check is load-bearing: %acme
::    validates port 80 at the domain itself and retries on a timer,
::    and a turf without a certificate is harmless.  both checks also
::    hang forever on any ship whose eyre answers an unbound path with
::    a redirect to /~/login, which is every ship running landscape:
::    iris follows the redirect with the relative location header, and
::    the runtime drops a request it cannot parse without answering.
::    so we install the turf as soon as the binding arrives and leave
::    the port-80 question to %acme.
::
/-  spider, dns
/+  strandio
=,  strand=strand:spider
^-  thread:spider
|=  arg=vase
|^
=/  m  (strand ,vase)
^-  form:m
=+  !<  [~ adr=address:dns]  arg
::
;<  our=ship  bind:m  get-our:strandio
?.  =(%pawn (clan:title our))
  %+  strand-fail:strandio  %ship-type-fail
  [>"can only set groundwire DNS for comets"< ~]
::
?:  (reserved:eyre if.adr)
  %+  strand-fail:strandio  %reserved-address
  [>"ip address {<if.adr>} is reserved"< ~]
::
;<  ~         bind:m  (watch:strandio /response collector /(scot %p our))
;<  ~         bind:m  (poke:strandio collector %dns-address !>(adr))
;<  =turf     bind:m  (take-turf adr)
;<  ~         bind:m  (leave:strandio /response collector)
;<  ~         bind:m  (install-domain:strandio turf)
::  one notice: the operator's login address just changed.  %acme
::  orders the certificate over port 80 at that name (a ship on 8080
::  needs port 80 forwarded to it); once it lands, plain http to the ip
::  redirects to https and fails, so the name is the address from then on.
=/  nam=tape  (trip (en-turf:html turf))
~>  %slog.[1 leaf+"%dns: this ship is now {nam}; once its certificate arrives (it needs port 80), log in at https://{nam}"]
(pure:m !>(turf))
::
::  the sponsor ship running %gw-dns
++  collector
  ^-  dock
  [~barmul-bolmet-ronlus-lighul--rovtun-satryc-moclug-daplyd %gw-dns]
::
::  wait for the domain bound to this address. %gw-dns answers a
::  watch with the binding it already holds, which names our old
::  address if we moved, so skip any binding for another address
++  take-turf
  |=  adr=address:dns
  =/  m  (strand ,turf)
  ^-  form:m
  |-  ^-  form:m
  =*  loop  $
  ;<  =cage  bind:m  (take-fact:strandio /response)
  ?>  ?=(%dns-binding p.cage)
  =/  =binding:dns  !<(binding:dns q.cage)
  ?.  =(adr address.binding)
    loop
  (pure:m turf.binding)
--
