package eventbus

import "./talloc"
import "base:intrinsics"
import "core:fmt"
import "core:mem"

Event_Type :: enum {
	Start,
	End,
	Message,
	Close,
}

Event :: struct($T: typeid) {
	type: T,
	data: [2]rawptr,
}

Event_Dispatch_Handler :: struct($T: typeid) {
	data:    rawptr,
	handler: proc(event: Event(T)),
}

Event_Bus :: struct($T: typeid) {
	subscriptions: map[T][dynamic]Event_Dispatch_Handler(T),
	allocator:     mem.Allocator,
}

register :: proc(
	bus: ^Event_Bus($T),
	event_type: T,
	handler: proc(event: Event(T)),
	data: rawptr = nil,
	loc := #caller_location,
) {
	edh := Event_Dispatch_Handler(T) {
		data    = data,
		handler = handler,
	}

	subs, ok := &bus.subscriptions[event_type]
	if !ok {
		bus.subscriptions[event_type] = make_dynamic_array_len_cap(
			[dynamic]Event_Dispatch_Handler(T),
			0,
			10,
			bus.allocator,
			loc,
		)
		subs = &bus.subscriptions[event_type]
	}

	append_elem(subs, edh, loc)
}

dispatch :: proc(bus: ^Event_Bus($T), event_type: T, data: rawptr) {
	handlers := bus.subscriptions[event_type]

	evt := Event(T) {
		type = event_type,
		data = [2]rawptr{data, nil},
	}

	for handler in handlers {
		evt.data[1] = handler.data
		handler.handler(evt)
	}
}

eventbus_create :: proc(
	$T: typeid,
	allocator := context.allocator,
	loc := #caller_location,
) -> ^Event_Bus(T) {
	bus, _ := new(Event_Bus(T), allocator, loc)
	bus.allocator = allocator
	bus.subscriptions = make_map(
		map[T][dynamic]Event_Dispatch_Handler(T),
		10,
		bus.allocator,
		loc,
	)

	return bus
}

eventbus_delete :: proc(bus: ^Event_Bus($T), loc := #caller_location) {

	for key in bus.subscriptions {
		delete_dynamic_array(bus.subscriptions[key], loc)
	}
	delete_map(bus.subscriptions)
	free(bus, bus.allocator, loc)
}

say_hi :: proc(event: Event(Event_Type)) {
	data := transmute([2]^string)event.data

	fmt.printf("%s %s\n", data[1]^, data[0]^)
}

main :: proc() {
	t: talloc.Tracking_Allocator
	context.allocator = talloc.talloc_enable(&t, context.allocator)
	defer talloc.talloc_destroy(&t)
	greet := "hello"
	msg := "world"
	msg2 := "planet"

	bus := eventbus_create(Event_Type)
	defer eventbus_delete(bus)
	register(bus, Event_Type.Start, say_hi)

	register(bus, Event_Type.End, say_hi, &greet)
	register(bus, Event_Type.Close, say_hi, &greet)
	register(bus, Event_Type.Close, say_hi, &greet)
	register(bus, Event_Type.Close, say_hi, &greet)
	register(bus, Event_Type.Close, say_hi, &greet)

	dispatch(bus, Event_Type.Start, &msg)
	dispatch(bus, Event_Type.Start, &msg2)
	dispatch(bus, Event_Type.Close, &msg2)
	dispatch(bus, Event_Type.End, &msg) // wont output anything since there is no handler registered
}
