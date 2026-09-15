/-  *gw-dns
/+  *test, gw-dns
=>
|%
++  mock-nym
  ^-  @t
  '.obstruct.adapts.galore.unite.despite.descale.behold.forego.remakes.devoid.refute.comprise'
::
++  mock-ship
  ^-  ship
  (en:ship:me:gw-dns mock-nym)
::
++  mock-words
  ^-  (list @t)
  :~  'obstruct'  'adapts'  'galore'  'unite'  'despite'  'descale'
      'behold'  'forego'  'remakes'  'devoid'  'refute'  'comprise'
  ==
--
|%
++  test-nym-words
  %+  expect-eq
    !>  mock-words
    !>  (nym-words:gw-dns mock-ship)
::
++  test-ladder
  ;:  weld
    %+  expect-eq
      !>  6
      !>  (lent (ladder:gw-dns mock-ship))
    %+  expect-eq
      !>  `turf`/me/groundwire/comprise/obstruct
      !>  (snag 0 (ladder:gw-dns mock-ship))
    %+  expect-eq
      !>  `turf`/me/groundwire/comprise/refute/adapts/obstruct
      !>  (snag 1 (ladder:gw-dns mock-ship))
    %+  expect-eq
      !>  (to-turf:gw-dns mock-words)
      !>  (rear (ladder:gw-dns mock-ship))
  ==
::
++  test-domain
  %+  expect-eq
    !>  'obstruct.comprise.groundwire.me'
    !>  (domain:gw-dns (snag 0 (ladder:gw-dns mock-ship)))
::
++  test-assign
  =/  rungs=(list turf)  (ladder:gw-dns mock-ship)
  ;:  weld
    %+  expect-eq
      !>  (snag 0 rungs)
      !>  (assign:gw-dns mock-ship ~)
    %+  expect-eq
      !>  (snag 1 rungs)
      !>  (assign:gw-dns mock-ship (silt ~[(snag 0 rungs)]))
    %+  expect-eq
      !>  (rear rungs)
      !>  (assign:gw-dns mock-ship (silt rungs))
  ==
::
++  test-request-json
  %+  expect-eq
    !>  ^-  json
        :-  %o
        %-  malt
        ^-  (list [@t json])
        :~  ['ship' n+'"sampel"']
            ['address' s+'1.2.3.4']
            ['domain' s+'a.b.groundwire.me']
            ['turf' a+~[s+'me' s+'groundwire' s+'b' s+'a']]
        ==
    !>  (request-json:gw-dns [~sampel [%if .1.2.3.4] /me/groundwire/b/a])
--
