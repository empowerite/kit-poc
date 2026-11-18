package style

// circled is whether a tab's number is drawn in a circle, as Circled was told. It starts on, as kittui starts.
var circled = true

// Circled tells the styles whether a tab's number is the circled dingbat digit, ➀ or ➊ when selected, or the plain
// digit, bold on the selected tab and dim on the others.
func Circled(on bool) { circled = on }

// IsCircled says whether a tab's number is drawn in a circle.
func IsCircled() bool { return circled }
