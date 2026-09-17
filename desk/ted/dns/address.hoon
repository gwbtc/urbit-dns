::  dns-address: get a groundwire.me domain and install it
::
::    a groundwire fork of the upstream thread. we ask the sponsor's
::    %gw-dns to bind our address, hear back which domain it assigned
::    us, as a turf like /me/groundwire/kazoo/bespoke, and hand that
::    turf to eyre, which orders the certificate through %acme.
::    produces the turf
::
/-  spider, dns
/+  strandio, libdns=dns
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
::  %acme answers its challenge on port 80, so check that first
;<  good=?    bind:m  (self-check-http:libdns |+if.adr 2)
?.  good
  %+  strand-fail:strandio  %bail-early-self-check
  [>"couldn't access ship on port 80"< ~]
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
;<  good=?    bind:m  (turf-confirm-install:libdns turf)
;<  ~         bind:m
  %+  app-message:strandio  %dns
  ?:  good
    [(cat 3 'confirmed access via ' (en-turf:html turf)) ~]
  :-  (cat 3 'unable to access via ' (en-turf:html turf))
  :~  leaf+"XX check via nslookup"
      leaf+"XX confirm port 80"
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
