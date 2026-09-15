/-  *gw-dns, dns
|_  [who=ship adr=address:dns]
++  grad  %noun
++  grow
  |%
  ++  noun  +<.grow
  --
++  grab
  |%
  +$  noun  [ship address:dns]
  ++  json
    =,  dejs:format
    %-  ot
    :~  [%ship |=(j=json ?>(?=([%s *] j) (rash +.j fed:ag)))]
        [%address |=(j=json ?>(?=([%s *] j) [%if (rash +.j ip4:eyre)]))]
    ==
  --
--
