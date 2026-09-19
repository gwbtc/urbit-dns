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
;<  ~         bind:m
  %^  app-message:strandio  %dns
    (cat 3 'request for DNS sent to ' (scot %p p:collector))
  ~
;<  ~         bind:m
  %^  app-message:strandio  %dns
    (cat 3 'awaiting response from ' (scot %p p:collector))
  ~
;<  =turf     bind:m  (take-turf adr)
;<  ~         bind:m  (leave:strandio /response collector)
;<  ~         bind:m  (install-domain:strandio turf)
;<  ~         bind:m
  %^  app-message:strandio  %dns
    (cat 3 'installed ' (en-turf:html turf))
  :~  leaf+"%acme orders the certificate next; it needs port 80"
      leaf+"at that name to reach this ship"
  ==
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
