::  %gw-dns: bind comets' ipv4 addresses to groundwire.me domains
::
::    a groundwire fork of %dns-collector. a comet pokes us with its
::    address, or the sponsor's operator pokes us with a comet and
::    its address, and we assign the comet the shortest domain under
::    the zone that no other comet holds. the request goes out on
::    /requests to a sidecar that writes the dns record and pokes
::    back %dns-complete; the binding then goes out to the comet on
::    /~comet. the sidecar keeps no state: on every watch of
::    /requests it hears every request still pending
::
/-  *gw-dns, dns
/+  gw-dns, default-agent, dbug, verb
=>
|%
+$  card  card:agent:gall
::
::  the work behind the agent arms, over the bowl and state
++  go
  |_  [=bowl:gall =state]
  ::  +dbg: the traces below print only when this is yes
  ++  dbg  ^-(? |)
  ::
  ++  handle-noun
    |=  non=*
    ^-  (quip card _state)
    ?:  ?=(%debug non)
      ~&  bowl=bowl
      ~&  state=state
      `state
    ~>  %slog.[2 leaf+"%gw-dns: ignored an unrecognized noun poke; the only one it takes is %debug"]
    `state
  ::
  ::  assign a domain and ask the sidecar to bind it. a comet that
  ::  already holds a domain keeps it: a repeat with the same address
  ::  just hears its binding again, and a new address re-requests the
  ::  same domain
  ++  bind
    |=  [who=ship adr=address:dns]
    ^-  (quip card _state)
    ?.  =(%pawn (clan:title who))
      ~|  [%gw-dns-comets-only who]  !!
    ?:  (reserved:eyre if.adr)
      ~|  [%gw-dns-reserved-address who if.adr]  !!
    =/  dun=(unit binding:dns)  (~(get by completed.state) who)
    ?:  &(?=(^ dun) =(adr address.u.dun))
      =.  requested.state  (~(del by requested.state) who)
      :_  state
      [%give %fact ~[/(scot %p who)] %dns-binding !>(u.dun)]~
    =/  req=(unit [=address:dns =turf])  (~(get by requested.state) who)
    ?:  &(?=(^ req) =(adr address.u.req))
      `state
    =/  =turf
      ?^  dun  turf.u.dun
      ?^  req  turf.u.req
      %+  assign:gw-dns  who
      %-  silt
      %+  murn  (weld ~(tap by completed.state) ~(tap by requested.state))
      |=  [=ship =address:dns =turf]
      ?:  =(ship who)  ~
      `turf
    =.  requested.state  (~(put by requested.state) who [adr turf])
    :_  state
    [%give %fact ~[/requests] %gw-dns-request !>(`request`[who adr turf])]~
  ::
  ::  the sidecar wrote the record: move the request to completed and
  ::  tell the comet. anything not matching a pending request is noise
  ++  complete
    |=  [who=ship =binding:dns]
    ^-  (quip card _state)
    =/  req=(unit [=address:dns =turf])  (~(get by requested.state) who)
    ?.  ?&  ?=(^ req)
            =(address.binding address.u.req)
            =(turf.binding turf.u.req)
        ==
      ~?  dbg  [%gw-dns-unknown-complete who binding]
      `state
    =:  requested.state  (~(del by requested.state) who)
        completed.state  (~(put by completed.state) who binding)
      ==
    :_  state
    [%give %fact ~[/(scot %p who)] %dns-binding !>(binding)]~
  --
--
::
=|  =state
%-  agent:dbug
%+  verb  |
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init  on-init:def
++  on-save  !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state old)
  ::
  ::  every epoch is a separate case here, and a state from an
  ::  earlier epoch steps through each later one in turn: reassign
  ::  domains under the new wordlist or zone, remember the old
  ::  domain in retired, and re-request every binding so the
  ::  sidecar writes the new records
  ?-  -.old
    %~.2026.09.15  `this(state old)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =*  go  ~(. ^go bowl state)
  =^  cards  state
    ?+  mark  (on-poke:def mark vase)
      %noun  (handle-noun:go !<(* vase))
    ::
        %dns-address
      (bind:go src.bowl !<(address:dns vase))
    ::
        %gw-dns-address
      ?>  (team:title [our src]:bowl)
      (bind:go !<([ship address:dns] vase))
    ::
        %dns-complete
      ?>  (team:title [our src]:bowl)
      (complete:go !<([ship binding:dns] vase))
    ==
  [cards this]
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%requests ~]
    :_  this
    %+  turn  ~(tap by requested.state)
    |=  [who=ship =address:dns =turf]
    ^-  card
    [%give %fact ~ %gw-dns-request !>(`request`[who address turf])]
  ::
      [@ ~]
    =/  who=(unit ship)  (slaw %p i.path)
    ?~  who  (on-watch:def path)
    ?~  dun=(~(get by completed.state) u.who)
      `this
    :_  this
    [%give %fact ~ %dns-binding !>(u.dun)]~
  ==
::
++  on-leave  on-leave:def
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  (on-peek:def path)
      [%x %requested ~]
    ``noun+!>(~(tap by requested.state))
  ::
      [%x %completed ~]
    ``noun+!>(~(tap by completed.state))
  ::
      [%x %domain @ ~]
    =/  who=(unit ship)  (slaw %p i.t.t.path)
    ?~  who  [~ ~]
    =/  =turf
      ?^  dun=(~(get by completed.state) u.who)
        turf.u.dun
      ?^  req=(~(get by requested.state) u.who)
        turf.u.req
      ~
    ?~  turf  [~ ~]
    ``json+!>(`json`s+(domain:gw-dns turf))
  ==
::
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
