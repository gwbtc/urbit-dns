/-  *gw-dns, dns
/+  mne=mnemonyms
/*  english  %txt  /fil/wordlists/english/txt
|%
::
::  a comet only reaches us once causeway has seen its spawn tx
::  confirmed onchain, so its nym is tweaked: one leading dot
++  me  ~(. me:mne [.y 128 english])
::
::  the words of a comet's nym, in order, without the leading dot
++  nym-words
  |=  who=ship
  ^-  (list @t)
  =/  nym=tape  (trip (de:ship:me who))
  |-
  ?~  nym  ~
  ?:  =('.' i.nym)
    $(nym t.nym)
  (scan nym (most dot (cook crip (plus low))))
::
::  a word list read as a domain under the zone, tld first
++  to-turf
  |=  words=(list @t)
  ^-  turf
  (weld zone (flop words))
::
::  every domain a ship may hold, shortest first: the first and last
::  word, then two from each end, and so on up to the whole nym.
::  the last rung is unique to the ship, so assignment always ends
++  ladder
  |=  who=ship
  ^-  (list turf)
  =/  words=(list @t)  (nym-words who)
  =/  n=@ud  (lent words)
  =/  k=@ud  1
  |-  ^-  (list turf)
  ?:  (gte (mul 2 k) n)
    [(to-turf words) ~]
  :-  (to-turf (weld (scag k words) (slag (sub n k) words)))
  $(k +(k))
::
::  the shortest rung nobody else holds
++  assign
  |=  [who=ship taken=(set turf)]
  ^-  turf
  =/  rungs=(list turf)  (ladder who)
  |-
  ?~  rungs  !!
  ?.  (~(has in taken) i.rungs)
    i.rungs
  ?~  t.rungs  i.rungs
  $(rungs t.rungs)
::
++  domain
  |=  =turf
  ^-  @t
  (en-turf:html turf)
::
++  request-json
  |=  =request
  ^-  json
  %-  pairs:enjs:format
  :~  ['ship' (ship:enjs:format ship.request)]
      ['address' s+(rsh 3 (scot %if if.address.request))]
      ['domain' s+(domain turf.request)]
      ['turf' a+(turn turf.request |=(t=@t s+t))]
  ==
--
