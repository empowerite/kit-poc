# modelsvg.jq - the diagrams of the model, a domain's cards and the lines between them, and an overview (jq module)
# ----------------------------------------------------------------------------------------------------------------------
# import "modelsvg" as modelsvg; with jq -L "${kit_jq}". Every function takes what model::build gives, {domains,
# entities, findings}. It holds one section for each concern, in the order a diagram is drawn:
#
#   text     the width of a string by a table of character widths, lines wrapped to a width, numbers, and escapes
#   colour   a domain's tint, stroke, and dark text color
#   cards    what a card of an entity holds, and how tall it is
#   layout   where each card of a domain goes: the row and column its hint gives, or else by layering
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

# text is a string escaped for the text of an element and the value of an attribute.
def text: clean | @html;

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
     cards: (reduce $names[] as $n ({};
       ($rows | index($cells[$n].row)) as $r
       | ($cols | index($cells[$n].col)) as $c
       | .[$n] = {row: $r, col: $c, x: (margin + $c * (card_w + col_gap)), y: $ys[$r], w: card_w, h: $heights[$r],
           card: $cards[$n]}))};

# ----------------------------------------------------------------------------------------------------------------------
# svg
# ----------------------------------------------------------------------------------------------------------------------

# style is the CSS of every diagram.
def style: [
  "    text { font-family: Inter, -apple-system, \"Segoe UI\", Helvetica, Arial, sans-serif; font-size: 13px; fill: #0f172a; }",
  "    .title { font-size: 24px; font-weight: 700; }",
  "    .intro { font-size: 13.5px; fill: #475569; }",
  "    .h { font-size: 15px; font-weight: 700; }",
  "    .w { font-size: 12.5px; fill: #1e293b; }",
  "    .ho { font-size: 12px; fill: #475569; }",
  "    .p { font-size: 12px; }",
  "    .m { font-family: \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace; font-size: 11.5px; fill: #334155; }",
  "    .f { font-family: \"SF Mono\", Menlo, Consolas, \"Liberation Mono\", monospace; font-size: 11px; fill: #334155; }",
  "    .lbl { font-size: 11.5px; fill: #475569; paint-order: stroke; stroke: #ffffff; stroke-width: 4px; stroke-linejoin: round; }",
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
    "  <rect x=\"\(margin)\" y=\"22\" width=\"6\" height=\"28\" rx=\"3\" fill=\"\($colour.stroke)\"/>",
    "  <text class=\"title\" x=\"\(margin + 18)\" y=\"45\" style=\"fill:\($colour.dark)\">\($title | text)</text>",
    ($intro | to_entries[]
      | "  <text class=\"intro\" x=\"\(margin)\" y=\"\(72 + .key * 19 | num)\">\(.value | text)</text>");

# band($x; $y; $w; $h; $r) is the path of a band $h tall across the top of a box with corners of radius $r.
def band($x; $y; $w; $h; $r):
  "M \($x | num) \($y + $h | num) V \($y + $r | num) A \($r) \($r) 0 0 1 \($x + $r | num) \($y | num)"
  + " H \($x + $w - $r | num) A \($r) \($r) 0 0 1 \($x + $w | num) \($y + $r | num) V \($y + $h | num) Z";

# dot($cx; $cy; $held) is the dot that says whether something is held: green and filled, or hollow.
def dot($cx; $cy; $held):
  if $held then "<circle cx=\"\($cx | num)\" cy=\"\($cy | num)\" r=\"4.5\" fill=\"#16a34a\"/>"
  else "<circle cx=\"\($cx | num)\" cy=\"\($cy | num)\" r=\"4\" fill=\"#ffffff\" stroke=\"#94a3b8\" stroke-width=\"1.5\"/>"
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
      | "  <text class=\"\($b.class)\" x=\"\($x + 12 | num)\" y=\"\($y + $b.top + $b.step - 5 + .key * $b.step | num)\">"
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
    "  <rect x=\"\($x | num)\" y=\"\($y | num)\" width=\"\($at.w | num)\" height=\"\($at.h | num)\" rx=\"9\" fill=\"none\""
    + " stroke=\"\($k.stroke)\" stroke-width=\"1.5\"" + (if $c.stub then " stroke-dasharray=\"6 4\"" else "" end) + "/>";

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
  | ([$l.width + 2 * margin, 600] | max) as $w
  | ($l.bottom + margin) as $h
  | [head($w; $h; $title; $desc; $colour; $l.intro),
     (if any($l.cards[]; .card.stub | not) then legend($w - margin) else empty end),
     ($names[] as $n | draw_card($l.cards[$n]; $colour)),
     "</svg>"]
  | join("\n");

# panels is where each domain's panel of the overview goes, {domain: {row, x, y, w, h, title, intro, pills}}: five to
# a row, by name, each as tall as the tallest of its row. A pill is an entity's name, wrapped into rows across the panel.
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
  "  <line x1=\"\($p.x | num)\" y1=\"\($p.y + $p.band | num)\" x2=\"\($p.x + $p.w | num)\" y2=\"\($p.y + $p.band | num)\""
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
    | "  <rect x=\"\($x | num)\" y=\"\($y | num)\" width=\"\($pill.w | num)\" height=\"22\" rx=\"11\" fill=\"\($k.tint)\""
      + " stroke=\"\($k.stroke)\" stroke-opacity=\".7\"" + (if $pill.stub then " stroke-dasharray=\"4 3\"" else "" end)
      + "/>",
      "  <text class=\"p\" text-anchor=\"middle\" x=\"\($x + $pill.w / 2 | num)\" y=\"\($y + 15 | num)\""
      + " style=\"fill:\($k.dark)\">\($pill.name | text)</text>"),
  "  <rect x=\"\($p.x | num)\" y=\"\($p.y | num)\" width=\"\($p.w | num)\" height=\"\($p.h | num)\" rx=\"12\" fill=\"none\""
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
       {stroke: "#475569", dark: "#0f172a"}; ["Each panel is a domain and names its entities. A dashed name is a stub."]),
     ($domains[] as $d | draw_panel($p[$d]; $model | colour($d))),
     "</svg>"]
  | join("\n");
