# changes.jq - which open changes the changes stage of kit flow lists (jq module)
#
# import "changes" as changes; with jq -L "${kit_jq}".
#
# see: modules/bash/changes.sh

import "forge" as forge;

# concerning($refs) keeps a change document, as forge.jq gives it, whose own number is one of $refs, or that closes an
# issue numbered one of them where the change is, as forge.jq's at says: one it closes in another repository is not
# the issue of that number here.
def concerning($refs):
  . as $change
  | select((.number as $n | $refs | index($n))
           or (.closes // [] | any(forge::at($change) and (.number as $n | $refs | index($n)))));
