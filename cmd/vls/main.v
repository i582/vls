module main

import ir
import parser

// // TODO: make this return !, after `cli` is changed too
// fn run_cli(cmd cli.Command) ! {
// 	validate_options(cmd)!
// 	run_server(cmd, true)!
// }
// fn setup_and_configure_io(cmd cli.Command, is_child bool) !io.ReaderWriter {
// 	socket_mode := cmd.flags.get_bool('socket') or { false }
// 	if socket_mode {
// 		socket_port := cmd.flags.get_int('port') or { 5007 }
// 		return new_socket_stream_server(socket_port, !is_child)
// 	} else {
// 		return new_stdio_stream()
// 	}
// }
// fn setup_logger(cmd cli.Command) jsonrpc.Interceptor {
// 	debug_mode := cmd.flags.get_bool('debug') or { false }
// 	return &LogRecorder{
// 		enabled: debug_mode
// 	}
// }
// fn validate_options(cmd cli.Command) ! {
// 	if timeout_seconds_val := cmd.flags.get_int('timeout') {
// 		if timeout_seconds_val < 0 {
// 			return error('timeout: should be not less than zero')
// 		}
// 	}
// 	if custom_vroot_path := cmd.flags.get_string('vroot') {
// 		if custom_vroot_path.len != 0 {
// 			if !os.exists(custom_vroot_path) {
// 				return error('Provided VROOT does not exist.')
// 			}
// 			if !os.is_dir(custom_vroot_path) {
// 				return error('Provided VROOT is not a directory.')
// 			}
// 		}
// 	}
// }
// fn run_server(cmd cli.Command, is_child bool) ! {
// 	// Setup the comm method and build the language server.
// 	mut stream := setup_and_configure_io(cmd, is_child)!
// 	mut ls := server.new()
// 	mut jrpc_server := &jsonrpc.Server{
// 		stream: stream
// 		interceptors: [
// 			setup_logger(cmd),
// 		]
// 		handler: ls
// 	}
// 	// if timeout_seconds_val := cmd.flags.get_int('timeout') {
// 	// 	ls.set_timeout_val(timeout_seconds_val)
// 	// }
// 	mut rw := unsafe { &server.ResponseWriter(jrpc_server.writer(own_buffer: true)) }
// 	// Show message that VLS is not yet ready!
// 	rw.show_message('
// VLS is early software.
// Please report your issue to github.com/vlang/vls if you encounter any problems.
// '.trim_indent(),
// 		.warning)
// 	spawn server.monitor_changes(mut ls, mut rw)
// 	jrpc_server.start()
// }

struct MyVisitor {
}

fn (m MyVisitor) visit(node ir.Node) bool {
	match node {
		ir.FunctionDeclaration {
			println(node.name.value)

			if node.name.value == 'main' {
				println('found main')
			}
		}
		else {}
	}
	return true
}

struct SymbolRegistrator {
mut:
	symbols Symbols
}

fn (mut m SymbolRegistrator) visit(node ir.Node) bool {
	match node {
		ir.FunctionDeclaration {
			m.symbols.functions[node.name.value] = node
		}
		ir.StructDeclaration {
			m.symbols.structs[node.name.value] = node
		}
		ir.VarDeclaration {
			for var in node.var_list.expressions {
				if var is ir.Identifier {
					m.symbols.vars[var.value] = node
				}
			}
		}
		ir.ImportDeclaration {
			println('import ${node.spec.path.value}')
		}
		else {}
	}
	return true
}

struct ArgumentMismatchInspection {
	ctx Context
mut:
	errors []string
}

fn (mut a ArgumentMismatchInspection) visit(node ir.Node) bool {
	match node {
		ir.CallExpr {
			name := node.name.value
			fun := a.ctx.symbols.functions[name] or { return true }
			arguments_count := node.args.args.len
			arguments_count_expected := fun.signature.parameters.parameters.len

			if arguments_count != arguments_count_expected {
				a.errors << '
				Argument missmatch for function `${name}`. 
				Expected ${arguments_count_expected} arguments, got ${arguments_count}
				'.trim_indent()
			}
		}
		else {}
	}
	return true
}

struct MismatchTypeInspection {
	ctx Context
mut:
	errors []string
}

fn (mut a MismatchTypeInspection) visit(node ir.Node) bool {
	match node {
		ir.CallExpr {
			name := node.name.value
			fun := a.ctx.symbols.functions[name] or { return true }

			argument_types := node.args.args.map(a.ctx.types[it.expr.id])
			parameter_types := fun.signature.parameters.parameters.map(it.typ.readable_name())

			for i in 0 .. argument_types.len {
				if argument_types[i] != parameter_types[i] {
					a.errors << '
					Type missmatch when call function ${name}. 
					Expected #${
						i + 1} argument of type ${parameter_types[i]}, got ${argument_types[i]}
					'.trim_indent()
				}
			}
		}
		else {}
	}
	return true
}

struct TypeInferrer {
	symbols Symbols
mut:
	types map[ir.ID]string
}

fn (mut m TypeInferrer) visit(node ir.Node) bool {
	match node {
		ir.StringLiteral {
			m.types[node.id] = 'string'
		}
		ir.IntegerLiteral {
			m.types[node.id] = 'int'
		}
		ir.TypeInitializer {
			typ := node.typ as ir.Type
			m.types[node.id] = typ.readable_name()
		}
		ir.VarDeclaration {
			mut expr := node.expression_list.expressions.first()
			expr.accept(mut m)
			m.types[node.id] = m.types[expr.id]
		}
		ir.Identifier {
			if node.value in m.symbols.vars {
				variable := m.symbols.vars[node.value]
				m.types[node.id] = m.types[variable.id]
			}
		}
		else {}
	}
	return true
}

struct UnknownFieldInspection {
	ctx Context
mut:
	errors []string
}

fn (mut a UnknownFieldInspection) visit(node ir.Node) bool {
	match node {
		ir.TypeInitializer {
			typ := node.typ as ir.Type
			name := typ.readable_name()
			struct_ := a.ctx.symbols.structs[name] or { return true }
			fields := struct_.field_list().map(it.name.value)
			for element in node.value.element_list.elements {
				if element.key.name() !in fields {
					a.errors << '
					Unknown field ${element.key.name()} for struct ${name}
					'.trim_indent()
				}
			}
		}
		else {}
	}
	return true
}

interface Inspection {
	ir.Visitor
	errors []string
}

struct Symbols {
mut:
	functions map[string]ir.FunctionDeclaration
	structs   map[string]ir.StructDeclaration
	vars      map[string]ir.VarDeclaration
}

struct Context {
	types   map[ir.ID]string
	symbols Symbols
}

fn main() {

	code := '
	
	struct Foo {
		name string
	}

	fn take_int(i int) int {
		return 100, 200
	}

	f := Foo{
		name: "foo"
		blabla: 100
	}
	
	// take_int(f)
	'.trim_indent()

	file := parser.parse_code(code)
	println(file.node)
	println(file)

	mut resolver := SymbolRegistrator{}
	file.accept(mut resolver)

	mut inferrer := TypeInferrer{
		symbols: resolver.symbols
	}
	file.accept(mut inferrer)

	ir.inspect(file, fn (it ir.Node) bool {
		if it is ir.FunctionDeclaration {
			println(it.name.value)
		}

		return true
	})

	ctx := Context{
		types: inferrer.types
		symbols: resolver.symbols
	}

	mut inspections := []Inspection{}
	inspections << ArgumentMismatchInspection{
		ctx: ctx
	}
	inspections << MismatchTypeInspection{
		ctx: ctx
	}
	inspections << UnknownFieldInspection{
		ctx: ctx
	}

	for inspection in inspections {
		mut visitor := inspection as ir.Visitor
		file.accept(mut visitor)
	}

	for inspection in inspections {
		for error in inspection.errors {
			println(error)
		}
	}

	// mut cmd := cli.Command{
	// 	name: 'vls'
	// 	version: server.meta.version
	// 	description: server.meta.description
	// 	execute: run_cli
	// 	posix_mode: true
	// }
	//
	// cmd.add_flags([
	// 	cli.Flag{
	// 		flag: .bool
	// 		name: 'child'
	// 		description: "Runs VLS in child process mode. Beware: using --child directly won't trigger features such as error reporting. Use it on your risk."
	// 	},
	// 	cli.Flag{
	// 		flag: .string
	// 		name: 'enable'
	// 		abbrev: 'e'
	// 		description: 'Enables specific language features.'
	// 	},
	// 	cli.Flag{
	// 		flag: .string
	// 		name: 'disable'
	// 		abbrev: 'd'
	// 		description: 'Disables specific language features.'
	// 	},
	// 	cli.Flag{
	// 		flag: .bool
	// 		name: 'generate-report'
	// 		description: "Generates an error report regardless of the language server's output."
	// 	},
	// 	cli.Flag{
	// 		flag: .bool
	// 		name: 'debug'
	// 		description: "Toggles language server's debug mode."
	// 	},
	// 	cli.Flag{
	// 		flag: .bool
	// 		name: 'socket'
	// 		description: 'Listens and communicates to the server through a TCP socket.'
	// 	},
	// 	cli.Flag{
	// 		flag: .int
	// 		default_value: ['5007']
	// 		name: 'port'
	// 		description: 'Port to use for socket communication. (Default: 5007)'
	// 	},
	// 	cli.Flag{
	// 		flag: .string
	// 		name: 'vroot'
	// 		required: false
	// 		description: 'Path to the V installation directory. By default, it will use the VROOT env variable or the current directory of the V executable.'
	// 	},
	// 	cli.Flag{
	// 		flag: .int
	// 		name: 'timeout'
	// 		default_value: ['15']
	// 		description: 'Number of SECONDS to be set for timeout/auto-shutdown. After n number of SECONDS, VLS will automatically shutdown. Set to 0 to disable it.'
	// 	},
	// ])
	//
	// cmd.parse(os.args)
}
