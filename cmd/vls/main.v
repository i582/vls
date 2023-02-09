module main

import structures.ropes
import cmd.ir

struct MyVisitor {
}

fn (m MyVisitor) visit(node ir.IrNode) bool {
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
	functions map[string]ir.FunctionDeclaration
}

fn (mut m SymbolRegistrator) visit(node ir.IrNode) bool {
	match node {
		ir.FunctionDeclaration {
			m.functions[node.name.value] = node
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

fn (mut a ArgumentMismatchInspection) visit(node ir.IrNode) bool {
	match node {
		ir.CallExpr {
			name := node.name.value
			fun := a.ctx.functions[name] or { return true }
			arguments_count := node.args.args.len
			arguments_count_expected := fun.parameters.parameters.len

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

fn (mut a MismatchTypeInspection) visit(node ir.IrNode) bool {
	match node {
		ir.CallExpr {
			name := node.name.value
			fun := a.ctx.functions[name] or { return true }

			argument_types := node.args.args.map(a.ctx.types[it.expr.id])
			parameter_types := fun.parameters.parameters.map(it.typ.readable_name())

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
mut:
	types map[ir.ID]string
}

fn (mut m TypeInferrer) visit(node ir.IrNode) bool {
	match node {
		ir.StringLiteral {
			m.types[node.id] = 'string'
		}
		ir.IntegerLiteral {
			m.types[node.id] = 'int'
		}
		else {}
	}
	return true
}

interface Inspection {
	ir.Visitor
	errors []string
}

struct Context {
	types     map[ir.ID]string
	functions map[string]ir.FunctionDeclaration
}

fn main() {
	code := '
module main

import os
import math as m

fn printf(s string, arg2 ...int) {}

fn main(name string, age int) {
	printf("Hello, World!", "error")
}
'.trim_indent()
	rope := ropes.new(code)

	mut parser := ir.new_parser()
	tree := parser.parse_string(source: code)

	root := tree.root_node()
	println(root)
	file := ir.convert_file(root, rope)

	println(file)

	mut resolver := SymbolRegistrator{}
	file.accept(mut resolver)

	mut inferrer := TypeInferrer{}
	file.accept(mut inferrer)

	ctx := Context{
		types: inferrer.types
		functions: resolver.functions
	}

	mut inspections := []Inspection{}
	inspections << ArgumentMismatchInspection{
		ctx: ctx
	}
	inspections << MismatchTypeInspection{
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
}
