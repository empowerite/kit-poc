package screens

import "golang.org/x/sys/unix"

// physicalMemory gives the machine's memory in bytes, 0 where the system does not say, which keeps only the latest
// workspace left.
func physicalMemory() uint64 {
	n, _ := unix.SysctlUint64("hw.memsize")
	return n
}
