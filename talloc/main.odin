package talloc

import "core:fmt"
import "core:mem"
import "base:runtime"

Tracking_Allocator :: mem.Tracking_Allocator

talloc_enable :: proc(track: ^Tracking_Allocator, alloc: runtime.Allocator) -> runtime.Allocator {
	mem.tracking_allocator_init(track, alloc)
	return mem.tracking_allocator(track)
}

talloc_destroy :: proc(track: ^Tracking_Allocator) {
	mem.tracking_allocator_destroy(track)
  talloc_print(track)
}

talloc_print :: proc(track: ^Tracking_Allocator) {
	if len(track.allocation_map) > 0 {
		fmt.eprintf(
			"=== %v allocations not freed: ===\n",
			len(track.allocation_map),
		)
		for _, entry in track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(track.bad_free_array) > 0 {
		fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
		for entry in track.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
}
