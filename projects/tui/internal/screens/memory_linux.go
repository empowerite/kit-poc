package screens

import "golang.org/x/sys/unix"

// physicalMemory gives the machine's memory in bytes, 0 where the system does not say, which keeps only the latest
// workspace left.
func physicalMemory() uint64 {
	var info unix.Sysinfo_t
	_ = unix.Sysinfo(&info)
	return uint64(info.Totalram) * uint64(info.Unit)
}
