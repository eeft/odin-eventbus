package eventbus

import "./talloc"
import "core:fmt"
import "core:os"
import "core:strconv"

Event_Type :: enum {
	Start,
	End,
	Message,
	Close,
}

Base_Event :: struct {}
Event :: struct {
	using base_event: Base_Event,
	event_t:          Event_Type,
	data:             [2]rawptr,
}

Event_Dispatch_Handler :: struct {
	event_t: Event_Type,
	data:    rawptr,
	handler: proc(event: ^Event),
}

Event_Bus :: struct {
	subscriptions: [dynamic]Event_Dispatch_Handler,
}

register :: proc(
	bus: ^Event_Bus,
	event_type: Event_Type,
	handler: proc(event: ^Event),
	data: rawptr = nil,
) {
	edh := Event_Dispatch_Handler {
		data    = data,
		event_t = event_type,
		handler = handler,
	}

	append(&bus.subscriptions, edh)
}

dispatch :: proc(bus: ^Event_Bus, event_type: Event_Type, data: rawptr) {
	handlers := bus.subscriptions

	evt := Event {
		event_t = event_type,
	}
	evt.data[0] = data
	for handler in handlers {
		if handler.event_t == event_type {
			evt.data[1] = handler.data
			handler.handler(&evt)
		}
	}
}

event_bus_create :: proc(allocator := context.allocator, loc := #caller_location) -> ^Event_Bus {
	bus, _ := new(Event_Bus, allocator, loc)

	return bus
}

event_bus_delete :: proc(event_bus: ^Event_Bus, allocator := context.allocator, loc := #caller_location) {
	handlers := event_bus.subscriptions
	free(event_bus, allocator, loc)
	delete_dynamic_array(handlers, loc)
}

say_hi :: proc(event: ^Event) {
	// horible example since you need to know that data is esentially a tuple of rawptrs, a struct would be better
	data := transmute([2]^string) event.data 

	fmt.printf("%s %s\n", data[1]^, data[0]^)
}

main :: proc() {
	t: talloc.Tracking_Allocator
	context.allocator = talloc.talloc_enable(&t, context.allocator)
	defer talloc.talloc_destroy(&t)

	bus := event_bus_create()
	defer event_bus_delete(bus)
	greet := "hello"

	register(bus, Event_Type.Start, say_hi, &greet)

	msg := "world"
	msg2 := "planet"

	dispatch(bus, Event_Type.Start, &msg)
	dispatch(bus, Event_Type.Start, &msg2)
	dispatch(bus, Event_Type.Close, &msg) // wont output anything since there is no handler registered
}
