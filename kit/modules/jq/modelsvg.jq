# modelsvg.jq - the diagrams of the model, a domain's cards and the lines between them, and an overview (jq module)
# ----------------------------------------------------------------------------------------------------------------------
# import "modelsvg" as modelsvg; with jq -L "${kit_jq}". Every function takes what model::build gives, {domains,
# entities, findings}. It holds one section for each concern, in the order a diagram is drawn:
#
#   text     the width of a string by a table of character widths, lines wrapped to a width, numbers, and escapes
#   colour   a domain's tint, stroke, and dark text color
#   cards    what a card of an entity holds, and how tall it is
#   layout   where each card of a domain goes: the row and column its hint gives, or else by layering
#   edges    the lines between the cards, on tracks in the gaps and gutters between them, and the labels at their ends
#   svg      domain($name), a domain's diagram, and overview, a panel for each domain
#
# The output is the same bytes for the same model, under any locale: every object is read by sorted key, every number
# is rounded to one decimal and printed by num, and nothing is counted in the order of a hash.
#
# see: modules/jq/model.jq, docs/model.md

import "model" as model;

# ----------------------------------------------------------------------------------------------------------------------
# text
# ----------------------------------------------------------------------------------------------------------------------

# num is a number rounded to one decimal, as text: 12 or 12.5, never 12.0 or 12.499999.
def num:
  (. * 10 | round) as $t
  | (if $t <= 0 then 0 - $t else $t end) as $a
  | (if $t < 0 then "-" else "" end) + ($a / 10 | floor | tostring)
    + (if $a % 10 == 0 then "" else "." + ($a % 10 | tostring) end);

# narrow_codes and wide_codes are the characters a sans-serif font sets narrower, and wider, than most.
def narrow_codes: "iljtfI.,:;'|!()[]/ \\-" | explode;
def wide_codes: "mwMW@" | explode;

# char_width($size; $mono) is the width of one character, given as its code, at a font size: a monospace character is
# 0.6 of the size; in a sans-serif font, a narrow one 0.29, a wide one 0.85, an ASCII capital 0.67, a digit 0.56, and
# any other 0.53.
def char_width($size; $mono):
  if $mono then $size * 0.6
  elif IN(narrow_codes[]) then $size * 0.29
  elif IN(wide_codes[]) then $size * 0.85
  elif . >= 65 and . <= 90 then $size * 0.67
  elif . >= 48 and . <= 57 then $size * 0.56
  else $size * 0.53 end;

# width($size; $mono) is the width of a string at a font size, with 3% to spare; width($size) is in the sans-serif font.
def width($size; $mono): ([explode[] | char_width($size; $mono)] | add // 0) * 1.03;
def width($size): width($size; false);

# clean is a value as one line of text: nothing is empty, a value that is not a string is its JSON, and every run of
# whitespace is one space.
def clean:
  (if type == "string" then . elif . == null then "" else tojson end)
  | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");

# pieces($size; $max; $mono) is a word in pieces no wider than $max: the word itself when it fits, and otherwise broken
# where it reaches $max.
def pieces($size; $max; $mono):
  if width($size; $mono) <= $max then .
  else
    (reduce (explode[] | [.] | implode) as $c ([""];
      if .[length - 1] == "" or (.[length - 1] + $c | width($size; $mono)) <= $max then .[length - 1] += $c
      else . + [$c] end))[]
  end;

# lines($size; $max; $mono) is a string wrapped into lines no wider than $max, broken at spaces, as an array.
def lines($size; $max; $mono):
  reduce (clean | split(" ")[] | select(. != "") | pieces($size; $max; $mono)) as $word ([];
    if length == 0 then [$word]
    elif (.[length - 1] + " " + $word | width($size; $mono)) <= $max then .[length - 1] += " " + $word
    else . + [$word] end);

# escape is a string escaped for the text of an element and the value of an attribute; text is a value as one line of
# text, escaped.
def escape: @html;
def text: clean | escape;

# tenth is a number rounded to one decimal, so the coordinate a function gives is the one num prints.
def tenth: (. * 10 | round) / 10;

# series is an array of names as an English list: A; A and B; A, B, and C.
def series:
  if length <= 2 then join(" and ")
  else (.[:-1] | join(", ")) + ", and " + .[-1] end;

# ----------------------------------------------------------------------------------------------------------------------
# colour
# ----------------------------------------------------------------------------------------------------------------------

# palette is the color of each of the release's domains, by the name of its directory: [tint, stroke, dark].
def palette: {
  actors: ["#fef3c7", "#b45309", "#78350f"],
  platform: ["#e0f2fe", "#0369a1", "#0c4a6e"],
  code: ["#dcfce7", "#15803d", "#14532d"],
  work: ["#ede9fe", "#6d28d9", "#4c1d95"],
  delivery: ["#ffe4e6", "#be123c", "#881337"],
  trust: ["#ccfbf1", "#0f766e", "#134e4a"],
  tools: ["#e2e8f0", "#475569", "#1e293b"],
  config: ["#e0e7ff", "#4338ca", "#312e81"],
  configuration: ["#e0e7ff", "#4338ca", "#312e81"],
  conversation: ["#fce7f3", "#be185d", "#831843"],
  content: ["#ecfccb", "#4d7c0f", "#365314"]
};

# others are the colors a domain outside the palette takes, by its place among the sorted domain names.
def others: [
  ["#ffedd5", "#c2410c", "#7c2d12"],
  ["#cffafe", "#0e7490", "#164e63"],
  ["#fae8ff", "#a21caf", "#701a75"],
  ["#fef9c3", "#a16207", "#713f12"],
  ["#d1fae5", "#047857", "#064e3b"],
  ["#dbeafe", "#1d4ed8", "#1e3a8a"]
];

# stub_colour is the grey of a stub's card and pill.
def stub_colour: {tint: "#f1f5f9", stroke: "#94a3b8", dark: "#334155"};

# domain_names are the names of the model's domains, sorted: those with a domain.yml and those an entity is in.
def domain_names: ([(.domains // {}) | keys[]] + [(.entities // {})[] | .domain | select(type == "string")]) | unique;

# colour($domain) is {tint, stroke, dark} of a domain of the model.
def colour($domain):
  (palette[$domain] // others[(([domain_names | to_entries[] | select(.value == $domain) | .key][0]) // 0) % 6])
  | {tint: .[0], stroke: .[1], dark: .[2]};

# ----------------------------------------------------------------------------------------------------------------------
# cards
# ----------------------------------------------------------------------------------------------------------------------

# card_w is the width of a card, card_in the width of the text in it, col_gap the gap between columns, row_gap the gap
# between rows, and margin the space around the diagram.
def card_w: 236;
def card_in: 212;
def col_gap: 64;
def row_gap: 56;
def margin: 32;

# block($class; $step; $lines) is one block of a card's text: lines of one CSS class, $step apart.
def block($class; $step; $lines): {class: $class, step: $step, lines: $lines};

# card($name) is what the card of an entity holds: its name and the size it is set in, its blocks of text (what it
# means; native or logical and over; its fields by status; a sum's variants), its footer, whether a field is held, and
# its height before its row stretches it.
def card($name):
  .entities[$name] as $e
  | ($e.stub == true) as $stub
  | ($e.sum == true) as $sum
  | [($e.fields // {}) | to_entries | sort_by(.key)[] | .value | select(type == "object")] as $fields
  | ([$fields[] | select(.status == "held")] | length > 0) as $held
  | ($name | width(15) * 1.05) as $name_w
  | [block("w"; 17; ($e.means | lines(12.5; card_in; false))),
     block("ho"; 16;
       if $e.layer == "native" then ["native" + (if ($e.tool | clean) == "" then "" else ": " + ($e.tool | clean) end)]
       elif $e.layer == "logical" then
         ["logical"]
         + (if ($e.over | type) == "array" and ($e.over | length) > 0
           then "over: " + ($e.over | map(clean) | join(", ")) | lines(12; card_in; false) else [] end)
       else [] end),
     block("ho"; 16;
       if $stub or $sum then []
       else [$fields | "\(map(select(.status == "held")) | length) held, \(map(select(.status == "planned")) | length)"
         + " planned, \(map(select(.status == "unused")) | length) unused"] end),
     block("m"; 15;
       if $sum and ($e.variants | type) == "object" then
         [$e.variants | to_entries | sort_by(.key)[]
           | (.key | clean) + "("
             + (if (.value | type) == "object"
               then [.value | to_entries | sort_by(.key)[] | "\(.key | clean): \(.value | clean)"] | join(", ")
               else "" end) + ")"
           | lines(11.5; card_in; true)[]]
       else [] end)
    | select(.lines | length > 0)] as $blocks
  | (if $stub then null
    else
      [$fields[] | select(.status == "held") | ."read-by" | select(type == "string") | clean | split(" ")[0]
        | select(. != "")] | unique
      | if length > 0 then "kit " + join(", kit ") else "not held yet" end
      | lines(11; card_in - 18; true)
    end) as $foot
  | (reduce $blocks[] as $b ({at: 42, first: true, blocks: []};
      (if .first then .at else .at + 6 end) as $start
      | .blocks += [$b + {top: $start}]
      | .at = $start + ($b.lines | length) * $b.step
      | .first = false)) as $placed
  | {name: $name, stub: $stub, held: $held,
     size: (if $name_w <= card_in then 15 else (15 * card_in / $name_w * 10 | floor) / 10 end),
     blocks: $placed.blocks, foot: $foot,
     foot_h: (if $foot == null then 0 else 14 + ($foot | length) * 14 + 6 end)}
  | .h = $placed.at + 10 + .foot_h;

# ----------------------------------------------------------------------------------------------------------------------
# layout
# ----------------------------------------------------------------------------------------------------------------------

# members($name) are the names of a domain's entities, sorted.
def members($name): [(.entities // {}) | to_entries[] | select(.value.domain == $name) | .key] | sort;

# hints($name; $names) are the hints of a domain's layout for its entities, {Entity: {row, col}}: only a hint of two
# numbers of zero or more counts, and it counts by its whole part.
def hints($name; $names):
  (.domains[$name].layout // {}) as $layout
  | if ($layout | type) != "object" then {}
    else
      reduce $names[] as $n ({};
        $layout[$n] as $h
        | if ($h | type) == "object" and ($h.row | type) == "number" and ($h.col | type) == "number" and $h.row >= 0
            and $h.col >= 0
          then .[$n] = {row: ($h.row | floor), col: ($h.col | floor)} else . end)
    end;

# needs($names) is, for each of $names, the others of $names it needs: those a relation of arity one or some goes to.
def needs($names):
  . as $model
  | reduce $names[] as $a ({};
      .[$a] = ([($model.entities[$a].relations // {}) | to_entries | sort_by(.key)[] | .value | select(type == "object")
        | select((.arity // "one") | IN("one", "some")) | .to
        | select(type == "string" and . != $a and IN($names[]))] | unique));

# visit($succ; $n) walks the needs from $n, depth first, in name order: on holds the entities on the current path,
# seen those it has finished, back each edge into an entity on the path, which it does not follow, and post the
# entities in the order it finished them.
def visit($succ; $n):
  .on[$n] = true
  | reduce $succ[$n][] as $m (.;
      if .on[$m] == true then .back[$n][$m] = true
      elif .seen[$m] == true then .
      else visit($succ; $m) end)
  | .on[$n] = false
  | .seen[$n] = true
  | .post += [$n];

# columns($names; $hints) is the column of each entity: its hint's, or else one right of the deepest entity that needs
# it, and 0 for one nothing needs. A cycle is broken at the edge back into an entity on the path, in name order.
def columns($names; $hints):
  needs($names) as $succ
  | (reduce $names[] as $n ({on: {}, seen: {}, back: {}, post: []};
      if .seen[$n] == true then . else visit($succ; $n) end)) as $walk
  | reduce ($walk.post | reverse[]) as $n ({};
      .[$n] = ($hints[$n].col
        // ((([$names[] as $a | select(any($succ[$a][]; . == $n) and $walk.back[$a][$n] != true) | .[$a]] | max) // -1)
          + 1)));

# cells($names; $hints) is the row and column of each entity, before empty rows and columns close up: a hinted entity
# in its cell, or the next free row below it when another hint took it first, by row, column, then name; every other
# entity in its column, below the hinted ones, by name.
def cells($names; $hints):
  columns($names; $hints) as $cols
  | (reduce ([$names[] | select($hints[.] != null)] | sort_by([$hints[.].row, $hints[.].col, .])[]) as $n ({};
      $hints[$n].col as $c
      | . as $taken
      | ($hints[$n].row | until(. as $r | any($taken[]; .row == $r and .col == $c) | not; . + 1)) as $r
      | .[$n] = {row: $r, col: $c})) as $hinted
  | reduce ([$names[] | select($hints[.] == null)] | sort_by([$cols[.], .])[]) as $n ($hinted;
      $cols[$n] as $c
      | .[$n] = {row: (([.[] | select(.col == $c) | .row] | max // -1) + 1), col: $c});

# layout($name) is where each card of a domain goes, and the size of the whole: {cards: {Entity: {row, col, x, y, w,
# h, card}}, width, top, bottom}. Empty rows and columns close up. A row is as tall as its tallest card, and the first
# starts under the title and the intro, wrapped to the width of the cards.
def layout($name):
  . as $model
  | members($name) as $names
  | hints($name; $names) as $hints
  | cells($names; $hints) as $cells
  | ([$cells[] | .row] | unique) as $rows
  | ([$cells[] | .col] | unique) as $cols
  | (reduce $names[] as $n ({}; .[$n] = ($model | card($n)))) as $cards
  | ([$cols | length, 2] | max) as $ncols
  | ($ncols * card_w + ($ncols - 1) * col_gap) as $width
  | ($model.domains[$name].intro | lines(13.5; $width; false)) as $intro
  | (44 + 14 + ($intro | length) * 19 + 26) as $top
  | ([range(0; $rows | length) as $i
      | [$names[] | select($cells[.].row == $rows[$i]) | $cards[.].h] | max]) as $heights
  | ([foreach $heights[] as $h ($top; . + $h + row_gap; . - $h - row_gap)]) as $ys
  | {width: $width, intro: $intro, top: $top,
     bottom: (if ($heights | length) == 0 then $top - row_gap else $ys[-1] + $heights[-1] end),
     rows: [range(0; $heights | length) as $i | {y: $ys[$i], h: $heights[$i]}],
     cards: (reduce $names[] as $n ({};
       ($rows | index($cells[$n].row)) as $r
       | ($cols | index($cells[$n].col)) as $c
       | .[$n] = {row: $r, col: $c, x: (margin + $c * (card_w + col_gap)), y: $ys[$r], w: card_w, h: $heights[$r],
           card: $cards[$n]}))};

# ----------------------------------------------------------------------------------------------------------------------
# edges
# ----------------------------------------------------------------------------------------------------------------------

# relation_text($name) is the label of a relation at the end of its line: its name, two spaces, and its arity as 1,
# 0..1, 0..*, or 1..*, then {ordered} for an ordered relation, and derived for a derived one.
def relation_text($name):
  "\($name | clean)  "
  + (if .arity == null or (.arity | type) == "string" then (.arity | model::arity_text) // (.arity | clean)
    else .arity | clean end)
  + (if .ordered == true then " {ordered}" else "" end)
  + (if .derived != null then "  derived" else "" end);

# lines_of($names) are the lines of a domain whose entities are $names, by entity, then relation: {key, kind, a, b,
# dashed, both, labels}, from a to b. kind is line, between two cards; loop, from a card to itself; or stub, to b, an
# entity of another domain, which has no card. A pair of inverse relations is one line with an arrow at both ends, drawn
# for the relation whose Entity.relation sorts first, and a relation that is its own inverse is a loop with one label.
# Any other relation is an arrow from its entity to where it goes, dashed when it is derived. A label is {role, text,
# far}: role a is at the line's start, b at its end, and far is the name of a stub's entity.
def lines_of($names):
  . as $model
  | [$names[] as $e
    | ($model.entities[$e].relations // {}) | to_entries | sort_by(.key)[]
    | select(.value | type == "object")
    | .key as $r
    | .value as $rel
    | "\($e).\($r)" as $key
    | ($rel.to | clean) as $t
    | ($t | IN($names[])) as $inside
    | ($rel.inverse | if type == "string" then . else "" end) as $inv
    | ($inv | split(".")) as $parts
    | (if $inside and $rel.derived == null and ($parts | length) == 2 and $parts[0] == $t
        then $model.entities[$t].relations[$parts[1]] else null end) as $other
    | (($other | type) == "object" and $other.inverse == $key and $other.to == $e) as $paired
    | {key: $key, a: $e, b: $t, dashed: ($rel.derived != null), both: $paired}
    | if ($inside | not) then . + {kind: "stub", labels: [{role: "b", text: ($rel | relation_text($r)), far: $t}]}
      elif $paired and $inv == $key then . + {kind: "loop", labels: [{role: "b", text: ($rel | relation_text($r))}]}
      elif $paired and $inv < $key then empty
      else
        . + {kind: (if $e == $t then "loop" else "line" end),
          labels: ((if $paired then [{role: "a", text: ($other | relation_text($parts[1]))}] else [] end)
            + [{role: "b", text: ($rel | relation_text($r))}])}
      end];

# side_of($cards; $me; $other) is the side of the card $me that a line to $other meets: the top when $other is in a
# row above, and else the bottom, so a line within a row runs under the row.
def side_of($cards; $me; $other): if $cards[$me].row > $cards[$other].row then "top" else "bottom" end;

# free($cards; $me; $step) is true when the cell $step columns from the card $me, in its row, holds no card, and is
# in the diagram or right of it.
def free($cards; $me; $step):
  $cards[$me] as $c
  | ($c.col + $step) as $col
  | $col >= 0 and (any($cards[]; .row == $c.row and .col == $col) | not);

# loop_side($cards; $me) is the side of the card $me that its loops go on: the right, or else the left, when the cell
# beside it is free, so their labels have room, and else the bottom.
def loop_side($cards; $me):
  if free($cards; $me; 1) then "right" elif free($cards; $me; -1) then "left" else "bottom" end;

# plans($cards) is how each line, given as input, runs: the line with {sa, sb, ga, gb, gutter}. sa and sb are the sides
# of the cards its two ends meet. ga and gb are the row gaps a top or bottom end opens into: the gap under the card's
# row for the bottom, and the gap above it for the top, where gap g lies under row g. A line whose two ends open into
# one gap runs along a track in that gap. Any other line runs along a track in the gap of its first end, along a track
# in a gutter between two columns, and along a track in the gap of its other end, so it never crosses a card. Its
# gutter lies between the two cards' columns, or right of the column they share: the one fewer lines have taken, then
# the one nearest the middle, then the leftmost.
def plans($cards):
  (reduce .[] as $l ({load: {}, plans: []};
    . as $state
    | (if $l.kind == "loop" then loop_side($cards; $l.a) else null end) as $loop
    | ($loop // (if $l.kind == "stub" then "bottom" else side_of($cards; $l.a; $l.b) end)) as $sa
    | (if $l.kind == "stub" then null else ($loop // side_of($cards; $l.b; $l.a)) end) as $sb
    | (if $sa == "top" then $cards[$l.a].row - 1 elif $sa == "bottom" then $cards[$l.a].row else null end) as $ga
    | (if $sb == "top" then $cards[$l.b].row - 1 elif $sb == "bottom" then $cards[$l.b].row else null end) as $gb
    | (if $ga != null and $gb != null and $ga != $gb then
        [$cards[$l.a].col, $cards[$l.b].col] as $c
        | (($c[0] + $c[1] + 1) / 2) as $mid
        | (if $c[0] == $c[1] then [$c[0] + 1] else [range(($c | min) + 1; ($c | max) + 1)] end)
        | min_by([($state.load["\(.)"] // 0), (. - $mid | fabs), .])
      else null end) as $gutter
    | .plans += [$l + {sa: $sa, sb: $sb, ga: $ga, gb: $gb, gutter: $gutter}]
    | if $gutter == null then . else .load["\($gutter)"] += 1 end)).plans;

# ends($cards) are the ends of the planned lines, given as input: {key, role, card, side, room, other}. room names the
# ends that share a stretch of card edge: the ends that open into one gap in one column, from the card over it and the
# card under it together, or else the ends on one side of a card. other is the x of the middle of the card at the
# line's other end. A stub has one end.
def ends($cards):
  [.[]
    | {key, role: "a", card: .a, side: .sa,
        room: (if .ga == null then "side \(.a) \(.sa)" else "gap \(.ga) \($cards[.a].col)" end),
        other: (if .kind == "stub" then 1000000 else $cards[.b].x + $cards[.b].w / 2 end)},
      (if .kind == "stub" then empty
      else
        {key, role: "b", card: .b, side: .sb,
          room: (if .gb == null then "side \(.b) \(.sb)" else "gap \(.gb) \($cards[.b].col)" end),
          other: ($cards[.a].x + $cards[.a].w / 2)}
      end)];

# ports($cards) is where each end, given as input, meets its card, {"<key> <role>": [x, y, side]}. The ends that share
# a room are spread evenly along it, below the band on the left and the right, ordered by the x of their other ends,
# then by key and role. So no two lines end at one point, and the legs of two lines in one gap never share an x.
def ports($cards):
  reduce (group_by(.room)[] | sort_by([.other, .key, .role]) | length as $n | to_entries[]
    | .key as $i
    | .value as $end
    | $cards[$end.card] as $c
    | {at: "\($end.key) \($end.role)", side: $end.side}
      + if $end.side == "top" or $end.side == "bottom" then
          {x: ($c.x + $c.w * ($i + 1) / ($n + 1) | tenth), y: (if $end.side == "top" then $c.y else $c.y + $c.h end)}
        else
          {x: (if $end.side == "right" then $c.x + $c.w else $c.x end),
            y: ($c.y + 30 + ($c.h - 30) * ($i + 1) / ($n + 1) | tenth)}
        end) as $p ({};
    .[$p.at] = [$p.x, $p.y, $p.side]);

# track_at($n; $i; $mid; $room) is where track $i of $n lies: the tracks are spread around $mid, 6 apart, or closer, so
# that all of them fit in $room.
def track_at($n; $i; $mid; $room): $mid + ($i - ($n - 1) / 2) * ([6, $room / ($n + 1)] | min) | tenth;

# tracks($rows) is where each planned line, given as input, runs in the gaps and the gutter it uses: {"<key> <gap>": y,
# "<key> gutter": x}. Each line has a track of its own in each, by key: around the middle of a gap, in its middle 44,
# and around the middle of a gutter, in its middle 28, which leaves 18 on each side for the loops on the cards' sides.
def tracks($rows):
  . as $plans
  | [([$plans[] | select(.ga != null and .gb != null) | {gap: (.ga, .gb), key}] | unique | group_by(.gap)[]
      | length as $n | to_entries[]
      | .key as $i
      | .value.gap as $g
      | {key: "\(.value.key) \($g)", value: track_at($n; $i; $rows[$g].y + $rows[$g].h + row_gap / 2; 44)}),
    ([$plans[] | select(.gutter != null) | {gutter, key}] | group_by(.gutter)[]
      | length as $n | to_entries[]
      | .key as $i
      | (margin + .value.gutter * (card_w + col_gap) - col_gap / 2) as $mid
      | {key: "\(.value.key) gutter", value: track_at($n; $i; $mid; 28)})]
  | from_entries;

# outward($side) is which way a line leaves a card's side: 1 to the right, -1 to the left.
def outward($side): if $side == "left" then -1 else 1 end;

# points($ports; $tracks) are the points of a planned line, given as input, from a to b: straight down 24 for a stub;
# out 14 from the side, along it, and back for a loop on a card's side; for a line within one gap, to its track, along
# it, and to the other end; for any other, to its track in its first gap, along it to the gutter, along the gutter to
# its track in the other gap, along that, and to the other end.
def points($ports; $tracks):
  $ports["\(.key) a"] as $pa
  | $ports["\(.key) b"] as $pb
  | if .kind == "stub" then [[$pa[0], $pa[1]], [$pa[0], $pa[1] + 24]]
    elif .ga == null then
      ($pa[0] + 14 * outward(.sa)) as $out
      | [[$pa[0], $pa[1]], [$out, $pa[1]], [$out, $pb[1]], [$pb[0], $pb[1]]]
    elif .ga == .gb then
      $tracks["\(.key) \(.ga)"] as $y
      | [[$pa[0], $pa[1]], [$pa[0], $y], [$pb[0], $y], [$pb[0], $pb[1]]]
    else
      $tracks["\(.key) \(.ga)"] as $ya
      | $tracks["\(.key) \(.gb)"] as $yb
      | $tracks["\(.key) gutter"] as $x
      | [[$pa[0], $pa[1]], [$pa[0], $ya], [$x, $ya], [$x, $yb], [$pb[0], $yb], [$pb[0], $pb[1]]]
    end;

# candidates($x; $y; $side; $leg) are the places a label can take by the end of a line at ($x, $y), nearest first:
# beside the tip of a stub, right then left; past a loop on a card's side, then over and under the end of it; or beside
# the leg the line runs straight from its end, $leg long, a row of text at a time, right then left, under a bottom end
# and over a top end. The row nearest the end is always a candidate, and the rows past the leg come last.
def candidates($x; $y; $side; $leg):
  if $side == "right" or $side == "left" then
    outward($side) as $d
    | (if $d > 0 then "start" else "end" end) as $anchor
    | {x: ($x + 20 * $d), y: ($y + 4), anchor: $anchor}, {x: ($x + 5 * $d), y: ($y - 4), anchor: $anchor},
      {x: ($x + 5 * $d), y: ($y + 12), anchor: $anchor}
  else
    (if $side == "tip" then 28, 40, 16, 52, 4
      else
        ([range(0; 8) | select(. == 0 or 13 + . * 12 + 3 <= $leg)] as $beside
          | $beside[], (range(0; 8) | select(IN($beside[]) | not)))
        | if $side == "top" then -5 - . * 12 else 13 + . * 12 end
      end) as $dy
    | (if $side == "tip" then 6 else 5 end) as $dx
    | {x: ($x + $dx), y: ($y + $dy), anchor: "start"}, {x: ($x - $dx), y: ($y + $dy), anchor: "end"}
  end;

# box($w) is the box [x0, y0, x1, y1] the letters of a label $w wide cover at its place: from the cap height to the
# descent of an 11.5px font.
def box($w): if .anchor == "start" then [.x, .y - 8.5, .x + $w, .y + 2.5] else [.x - $w, .y - 8.5, .x, .y + 2.5] end;

# overlaps($a; $b) is true when two boxes overlap.
def overlaps($a; $b): $a[0] < $b[2] and $b[0] < $a[2] and $a[1] < $b[3] and $b[1] < $a[3];

# label_reach is how far the text of a label may be from the end of its line, in x and in y, so it reads as that end's.
def label_reach: 40;

# place($lines; $ports; $cards; $paths) are the labels of the lines: {key, role, at, text, far, x, y, anchor, box},
# where at is the entity at the label's end. Each takes the candidate that costs least: a card or a label placed
# before it that it covers costs 1000, as does reaching left of the diagram; each candidate costs one more than the one
# before it, so the nearest wins a tie; and a segment of a line it crosses costs 3, so a label moves a row or two to
# keep clear of a line, and no further, because the halo of its text hides a line it crosses.
def place($lines; $ports; $cards; $paths):
  [$cards[] | [.x, .y, .x + .w, .y + .h]] as $walls
  | [$paths[].points | range(1; length) as $i | [.[$i - 1], .[$i]]
      | [([.[0][0], .[1][0]] | min) - 1, ([.[0][1], .[1][1]] | min) - 1, ([.[0][0], .[1][0]] | max) + 1,
         ([.[0][1], .[1][1]] | max) + 1]] as $segments
  | reduce ($lines[] as $l | $l.labels[]
      | . + {key: $l.key, kind: $l.kind, at: (if .role == "a" or $l.kind == "stub" then $l.a else $l.b end),
          port: $ports["\($l.key) \(if $l.kind == "stub" then "a" else .role end)"]}) as $label ([];
    . as $placed
    | (($label.text + (if $label.far == null then "" else "  " + $label.far end)) | width(11.5)) as $w
    | ($paths[] | select(.key == $label.key) | .points | if $label.role == "a" then . else reverse end) as $route
    | ($route[0][1] - $route[1][1] | fabs) as $leg
    | [candidates($label.port[0]; $label.port[1]; if $label.kind == "stub" then "tip" else $label.port[2] end; $leg),
        (if ($label.port[2] == "top" or $label.port[2] == "bottom") and ($route | length) >= 3 and $leg <= 44 then
          (if $route[2][0] > $route[1][0] then 1 else -1 end) as $d
          | (-4, 12) as $dy
          | {x: ($route[1][0] + 5 * $d), y: ($route[1][1] + $dy), anchor: (if $d > 0 then "start" else "end" end)}
        else empty end)
        | {x: (.x | tenth), y: (.y | tenth), anchor} | .box = (box($w) | map(tenth))] as $all
    | $route[0] as $end
    | ([$all[] | .box as $b
        | select(([0, $b[0] - $end[0], $end[0] - $b[2]] | max) <= label_reach
          and ([0, $b[1] - $end[1], $end[1] - $b[3]] | max) <= label_reach)]
      | if length == 0 then [$all[0]] else . end) as $options
    | ([$options | to_entries[] | .key as $rank | .value.box as $b
        | {rank: $rank, cost: ($rank
            + 1000 * ([$walls[], ($placed[].box | [.[0] - 6, .[1], .[2] + 6, .[3]]) | select(overlaps(.; $b))]
              | length)
            + (if $b[0] < 4 then 1000 else 0 end)
            + 3 * ([$segments[] | select(overlaps(.; $b))] | length)),
           at: .value}]
      | min_by([.cost, .rank]).at) as $at
    | . + [{key: $label.key, role: $label.role, at: $label.at, text: $label.text, far: $label.far} + $at]);

# routes($layout) are the lines of a domain laid out as $layout: {paths: [{key, kind, a, b, class, points}], labels}.
def routes($layout):
  ($layout.cards | keys) as $names
  | (lines_of($names) | plans($layout.cards)) as $lines
  | ($lines | ends($layout.cards) | ports($layout.cards)) as $ports
  | ($lines | tracks($layout.rows)) as $tracks
  | [$lines[]
      | {key, kind, a, b, class: ("edge" + (if .both then " both" else "" end) + (if .dashed then " dash" else "" end)),
          points: points($ports; $tracks)}] as $paths
  | {paths: $paths, labels: place($lines; $ports; $layout.cards; $paths)};

# edges($name) are the lines of a domain's diagram and their labels, as routes gives them.
def edges($name): routes(layout($name));

# ----------------------------------------------------------------------------------------------------------------------
# svg
# ----------------------------------------------------------------------------------------------------------------------

# style is the CSS of every diagram.
def style: [
  "    text { font-family: Inter, -apple-system, \"Segoe UI\", Helvetica, Arial, sans-serif; font-size: 13px;"
    + " fill: #0f172a; }",
  "    .title { font-size: 24px; font-weight: 700; }",
  "    .intro { font-size: 13.5px; fill: #475569; }",
  "    .h { font-size: 15px; font-weight: 700; }",
  "    .w { font-size: 12.5px; fill: #1e293b; }",
  "    .ho { font-size: 12px; fill: #475569; }",
  "    .p { font-size: 12px; }",
  "    .m { font-family: \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace; font-size: 11.5px;"
    + " fill: #334155; }",
  "    .f { font-family: \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace; font-size: 11px;"
    + " fill: #334155; }",
  "    .lbl { font-size: 11.5px; fill: #475569; paint-order: stroke; stroke: #ffffff; stroke-width: 4px;"
    + " stroke-linejoin: round; }",
  "    .far { fill: #94a3b8; }",
  "    .edge { stroke: #475569; stroke-width: 1.5; fill: none; marker-end: url(#arrow); }",
  "    .both { marker-start: url(#arrow); }",
  "    .dash { stroke-dasharray: 5 4; }"
];

# head($w; $h; $title; $desc; $colour; $intro) are the opening lines of a diagram $w by $h: the svg element, its title
# and desc, the arrow and the style, the white background, and the title and intro drawn at the top.
def head($w; $h; $title; $desc; $colour; $intro):
  ($w | ceil) as $w
  | ($h | ceil) as $h
  | "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \($w | num) \($h | num)\" width=\"\($w | num)\""
    + " height=\"\($h | num)\" role=\"img\" aria-labelledby=\"title desc\">",
    "  <title id=\"title\">\($title | text)</title>",
    "  <desc id=\"desc\">\($desc | text)</desc>",
    "  <defs>",
    "    <marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"8\" markerHeight=\"8\""
    + " orient=\"auto-start-reverse\">",
    "      <path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#475569\"/>",
    "    </marker>",
    "    <style>",
    style[],
    "    </style>",
    "  </defs>",
    "  <rect x=\"0.5\" y=\"0.5\" width=\"\($w - 1 | num)\" height=\"\($h - 1 | num)\" rx=\"14\" fill=\"#ffffff\""
    + " stroke=\"#e2e8f0\"/>",
    "  <rect x=\"\(margin | num)\" y=\"22\" width=\"6\" height=\"28\" rx=\"3\" fill=\"\($colour.stroke)\"/>",
    "  <text class=\"title\" x=\"\(margin + 18 | num)\" y=\"45\" style=\"fill:\($colour.dark)\">"
    + "\($title | text)</text>",
    ($intro | to_entries[]
      | "  <text class=\"intro\" x=\"\(margin | num)\" y=\"\(72 + .key * 19 | num)\">\(.value | text)</text>");

# band($x; $y; $w; $h; $r) is the path of a band $h tall across the top of a box with corners of radius $r.
def band($x; $y; $w; $h; $r):
  "M \($x | num) \($y + $h | num) V \($y + $r | num) A \($r | num) \($r | num) 0 0 1 \($x + $r | num) \($y | num)"
  + " H \($x + $w - $r | num) A \($r | num) \($r | num) 0 0 1 \($x + $w | num) \($y + $r | num) V \($y + $h | num) Z";

# dot($cx; $cy; $held) is the dot that says whether something is held: green and filled, or hollow.
def dot($cx; $cy; $held):
  if $held then "<circle cx=\"\($cx | num)\" cy=\"\($cy | num)\" r=\"4.5\" fill=\"#16a34a\"/>"
  else
    "<circle cx=\"\($cx | num)\" cy=\"\($cy | num)\" r=\"4\" fill=\"#ffffff\" stroke=\"#94a3b8\""
    + " stroke-width=\"1.5\"/>"
  end;

# draw_card($at; $colour) are the lines of a card at its place in the layout: the white box, the tinted band and the
# name on it, its blocks of text, its footer, and the outline, dashed and grey for a stub.
def draw_card($at; $colour):
  $at.card as $c
  | (if $c.stub then stub_colour else $colour end) as $k
  | $at.x as $x
  | $at.y as $y
  | "  <rect x=\"\($x | num)\" y=\"\($y | num)\" width=\"\($at.w | num)\" height=\"\($at.h | num)\" rx=\"9\""
    + " fill=\"#ffffff\"/>",
    "  <path d=\"\(band($x; $y; $at.w; 30; 9))\" fill=\"\($k.tint)\"/>",
    "  <line x1=\"\($x | num)\" y1=\"\($y + 30 | num)\" x2=\"\($x + $at.w | num)\" y2=\"\($y + 30 | num)\""
    + " stroke=\"\($k.stroke)\" stroke-opacity=\".35\"/>",
    "  <text class=\"h\" x=\"\($x + 12 | num)\" y=\"\($y + 20.5 | num)\" style=\"fill:\($k.dark)"
    + (if $c.size == 15 then "" else ";font-size:\($c.size | num)px" end) + "\">\($c.name | text)</text>",
    ($c.blocks[] as $b
      | $b.lines | to_entries[]
      | "  <text class=\"\($b.class)\" x=\"\($x + 12 | num)\""
        + " y=\"\($y + $b.top + $b.step - 5 + .key * $b.step | num)\">"
        + "\(.value | text)</text>"),
    (if $c.foot == null then empty
    else
      ($y + $at.h - $c.foot_h) as $fy
      | "  <line x1=\"\($x + 12 | num)\" y1=\"\($fy | num)\" x2=\"\($x + $at.w - 12 | num)\" y2=\"\($fy | num)\""
        + " stroke=\"#e2e8f0\"/>",
        "  " + dot($x + 19; $fy + 10.5; $c.held),
        ($c.foot | to_entries[]
          | "  <text class=\"f\" x=\"\($x + 30 | num)\" y=\"\($fy + 14 + .key * 14 | num)\">\(.value | text)</text>")
    end),
    "  <rect x=\"\($x | num)\" y=\"\($y | num)\" width=\"\($at.w | num)\" height=\"\($at.h | num)\" rx=\"9\""
    + " fill=\"none\" stroke=\"\($k.stroke)\" stroke-width=\"1.5\""
    + (if $c.stub then " stroke-dasharray=\"6 4\"" else "" end) + "/>";

# draw_path is the line of a path routes gives.
def draw_path:
  "  <path class=\"\(.class)\" d=\"M " + (.points | map("\(.[0] | num) \(.[1] | num)") | join(" L ")) + "\"/>";

# draw_label is the text of a label routes gives, its spaces kept, with a stub's entity in grey after it.
def draw_label:
  "  <text class=\"lbl\" xml:space=\"preserve\" x=\"\(.x | num)\" y=\"\(.y | num)\""
  + (if .anchor == "end" then " text-anchor=\"end\"" else "" end) + ">\(.text | escape)"
  + (if .far == null then "" else "  <tspan class=\"far\">\(.far | escape)</tspan>" end) + "</text>";

# legend($right) is the key to the footer's dot, at the top right of a diagram whose right edge is $right.
def legend($right):
  "  <g transform=\"translate(\($right - 230 | num),30)\">" + dot(5; 0; true)
  + "<text class=\"ho\" x=\"16\" y=\"3.5\" style=\"font-size:11.5px\">held by kit</text>" + dot(112; 0; false)
  + "<text class=\"ho\" x=\"123\" y=\"3.5\" style=\"font-size:11.5px\">not held yet</text></g>";

# domain($name) is the diagram of a domain, as SVG text: a card for each of its entities, where layout puts it.
def domain($name):
  . as $model
  | layout($name) as $l
  | colour($name) as $colour
  | (($model.domains[$name].name // $name) | clean) as $title
  | ($l.cards | keys) as $names
  | (if ($names | length) == 0 then "The \($title) domain holds no entity."
    else "Entities of the \($title) domain: \($names | series)." end) as $desc
  | ($model | routes($l)) as $r
  | ([$l.width + 2 * margin, 600, ($r.labels[] | .box[2] + margin), ($r.paths[].points[][0] + margin)] | max) as $w
  | ([$l.bottom, ($r.labels[] | .box[3]), ($r.paths[].points[][1])] | max + margin) as $h
  | [head($w; $h; $title; $desc; $colour; $l.intro),
     (if any($l.cards[]; .card.stub | not) then legend($w - margin) else empty end),
     ($r.paths[] | draw_path),
     ($names[] as $n | draw_card($l.cards[$n]; $colour)),
     ($r.labels[] | draw_label),
     "</svg>"]
  | join("\n");

# panels is where each domain's panel of the overview goes, {domain: {row, x, y, w, h, title, intro, pills}}: five
# to a row, by name, each as tall as the tallest of its row. A pill is an entity's name, wrapped into rows across the
# panel.
def panels:
  . as $model
  | domain_names as $domains
  | 220 as $pw
  | (reduce $domains[] as $d ({};
      ($model.domains[$d].intro | lines(11.5; $pw - 28; false)) as $intro
      | (35 + ($intro | length) * 15) as $band
      | (reduce ($model | members($d))[] as $e ({x: 0, row: 0, pills: []};
          (($e | width(12)) + 18) as $w
          | (if .x > 0 and .x + $w > $pw - 24 then .x = 0 | .row += 1 else . end)
          | .pills += [{name: $e, stub: ($model.entities[$e].stub == true), x: .x, row: .row, w: $w}]
          | .x += $w + 6)) as $p
      | .[$d] = {title: (($model.domains[$d].name // $d) | clean), intro: $intro, band: $band, pills: $p.pills,
          need: ($band + 14 + (if ($p.pills | length) == 0 then 0 else ($p.row + 1) * 28 - 6 end) + 14)})) as $sized
  | ([range(0; $domains | length; 5) as $i | [$domains[$i:$i + 5][] | $sized[.].need] | max]) as $heights
  | ([foreach $heights[] as $h (110; . + $h + 18; . - $h - 18)]) as $ys
  | reduce range(0; $domains | length) as $i ({};
      ($i / 5 | floor) as $r
      | .[$domains[$i]] = $sized[$domains[$i]]
        + {row: $r, x: (margin + ($i % 5) * ($pw + 18)), y: $ys[$r], w: $pw, h: $heights[$r]});

# draw_panel($p; $colour) are the lines of one panel of the overview: the box, the tinted band with the domain's name
# and intro, and a pill for each entity, dashed and grey for a stub.
def draw_panel($p; $colour):
  "  <rect x=\"\($p.x | num)\" y=\"\($p.y | num)\" width=\"\($p.w | num)\" height=\"\($p.h | num)\" rx=\"12\""
    + " fill=\"#ffffff\"/>",
  "  <path d=\"\(band($p.x; $p.y; $p.w; $p.band; 12))\" fill=\"\($colour.tint)\"/>",
  "  <line x1=\"\($p.x | num)\" y1=\"\($p.y + $p.band | num)\" x2=\"\($p.x + $p.w | num)\""
    + " y2=\"\($p.y + $p.band | num)\""
    + " stroke=\"\($colour.stroke)\" stroke-opacity=\".35\"/>",
  "  <text class=\"h\" x=\"\($p.x + 14 | num)\" y=\"\($p.y + 22 | num)\" style=\"fill:\($colour.dark);font-size:16px\">"
    + "\($p.title | text)</text>",
  ($p.intro | to_entries[]
    | "  <text class=\"ho\" x=\"\($p.x + 14 | num)\" y=\"\($p.y + 40 + .key * 15 | num)\" style=\"font-size:11.5px\">"
      + "\(.value | text)</text>"),
  ($p.pills[] as $pill
    | (if $pill.stub then stub_colour else $colour end) as $k
    | ($p.x + 12 + $pill.x) as $x
    | ($p.y + $p.band + 14 + $pill.row * 28) as $y
    | "  <rect x=\"\($x | num)\" y=\"\($y | num)\" width=\"\($pill.w | num)\" height=\"22\" rx=\"11\""
      + " fill=\"\($k.tint)\""
      + " stroke=\"\($k.stroke)\" stroke-opacity=\".7\"" + (if $pill.stub then " stroke-dasharray=\"4 3\"" else "" end)
      + "/>",
      "  <text class=\"p\" text-anchor=\"middle\" x=\"\($x + $pill.w / 2 | num)\" y=\"\($y + 15 | num)\""
      + " style=\"fill:\($k.dark)\">\($pill.name | text)</text>"),
  "  <rect x=\"\($p.x | num)\" y=\"\($p.y | num)\" width=\"\($p.w | num)\" height=\"\($p.h | num)\" rx=\"12\""
    + " fill=\"none\""
    + " stroke=\"\($colour.stroke)\" stroke-width=\"1.5\"/>";

# overview is the diagram of the whole model, as SVG text: a panel for each domain, five to a row.
def overview:
  . as $model
  | panels as $p
  | domain_names as $domains
  | ([$domains | length, 5] | min) as $n
  | ([margin * 2 + $n * 220 + ([$n - 1, 0] | max) * 18, 600] | max) as $w
  | (([$p[] | .y + .h] | max) // 110) as $bottom
  | [head($w; $bottom + margin; "Entities";
       "The entities of the model in \($domains | length) domains, each domain with the entities it holds.";
       {stroke: "#475569", dark: "#0f172a"};
       ["Each panel is a domain and names its entities. A dashed name is a stub."]),
     ($domains[] as $d | draw_panel($p[$d]; $model | colour($d))),
     "</svg>"]
  | join("\n");
