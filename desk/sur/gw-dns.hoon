/-  dns
|%
::
::  the state head tag names the epoch: the wordlist revision and
::  zone the domains in it were assigned under. a new wordlist or
::  zone gets a new tag, and +on-load walks epochs in order
+$  epoch  @ta
++  this-epoch  %~.2026.09.15
::
::  tld-first zone every domain hangs under: groundwire.me
++  zone  /me/groundwire
::
::  what the sidecar receives on /requests
+$  request  [=ship =address:dns =turf]
::
+$  state
  $:  %~.2026.09.15
      requested=(map ship [=address:dns =turf])
      completed=(map ship binding:dns)
      retired=(map turf turf)
  ==
+$  versioned-state
  $%  state
  ==
::
+$  action
  $%  [%dns-address =address:dns]
      [%gw-dns-address =ship =address:dns]
      [%dns-complete =ship =binding:dns]
  ==
+$  update
  $%  [%gw-dns-request =request]
      [%dns-binding =binding:dns]
  ==
--
