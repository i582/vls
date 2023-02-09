module ir

import tree_sitter
import tree_sitter_v as v

__global counter = 0

pub fn convert_file(node Node, text tree_sitter.SourceText) File {
	module_clause := field_opt(node, 'module_clause') or { Node{} }

	stmts_node := field(node, 'stmts')

	mut stmts := []IrNode{}
	mut sibling := stmts_node
	for {
		stmts << convert_stmt(sibling, text) or { continue }
		sibling = sibling.next_sibling() or { break }
	}

	return File{
		id: counter++
		node: node
		module_clause: convert_node(module_clause, text) or {
			panic('can\'t convert node ${node.type_name}')
		}
		imports: convert_import_list(node, text)
		stmts: stmts
	}
}

fn convert_module_clause(node Node, text tree_sitter.SourceText) ModuleClause {
	return ModuleClause{
		id: counter++
		node: node
		name: convert_identifier(field_id(node, 0), text)
	}
}

fn convert_import_list(node Node, text tree_sitter.SourceText) ImportList {
	mut imports := []ImportDeclaration{}
	for i := u32(0); i < node.child_count(); i++ {
		child := node.child(i) or { continue }
		if child.type_name == .import_declaration {
			imports << convert_import_declaration(child, text)
		}
	}
	return ImportList{
		id: counter++
		node: node
		imports: imports
	}
}

fn convert_import_declaration(node Node, text tree_sitter.SourceText) ImportDeclaration {
	return ImportDeclaration{
		id: counter++
		node: node
		spec: convert_import_spec(node, text)
	}
}

fn convert_import_spec(node Node, text tree_sitter.SourceText) ImportSpec {
	path := field(node, 'import_path')
	alias := field_opt(node, 'import_alias') or { Node{} }
	return ImportSpec{
		id: counter++
		node: node
		path: convert_import_path(path, text)
		alias: convert_import_alias(alias, text) or { IrNode(null_node) }
	}
}

fn convert_import_path(node Node, text tree_sitter.SourceText) ImportPath {
	return ImportPath{
		id: counter++
		node: node
		value: node.text(text)
	}
}

fn convert_import_alias(node Node, text tree_sitter.SourceText) ?IrNode {
	if node == Node{} {
		return none
	}
	name := field_opt(node, 'name')?
	return ImportAlias{
		id: counter++
		node: node
		name: name.text(text)
	}
}

fn convert_node(node Node, text tree_sitter.SourceText) ?IrNode {
	match node.type_name {
		.identifier {
			return convert_identifier(node, text)
		}
		.call_expression {
			return convert_call_expression(node, text)
		}
		.interpreted_string_literal {
			return convert_string_literal(node, text)
		}
		.int_literal {
			return convert_int_literal(node, text)
		}
		.function_declaration {
			return convert_function_declaration(node, text)
		}
		.module_clause {
			return convert_module_clause(node, text)
		}
		else {
			return null_node
		}
	}
}

fn field(node Node, name string) Node {
	return node.child_by_field_name(name) or { panic(err) }
}

fn field_opt(node Node, name string) ?tree_sitter.Node[v.NodeType] {
	return node.child_by_field_name(name)
}

fn field_id(node Node, id u32) Node {
	return node.child(id) or { panic(err) }
}

fn has_field(node Node, name string) bool {
	node.child_by_field_name(name) or { return false }
	return true
}

fn map_child[T, U](n tree_sitter.Node[T], cb fn (n tree_sitter.Node[T]) ?U) []U {
	mut result := []U{}
	for i := u32(0); i < n.child_count(); i++ {
		result << cb(n.child(i) or { panic("can't find #${i} node") }) or { continue }
	}
	return result
}

fn convert_identifier(node Node, text tree_sitter.SourceText) Identifier {
	return Identifier{
		id: counter++
		node: node
		value: node.text(text)
	}
}

pub fn convert_function_declaration(node Node, text tree_sitter.SourceText) FunctionDeclaration {
	name := convert_identifier(field(node, 'name'), text)
	parameters_node := field(node, 'parameters')
	parameters := convert_parameter_list(parameters_node, text)
	block := convert_block(field(node, 'body'), text)
	return FunctionDeclaration{
		id: counter++
		node: node
		name: name
		parameters: parameters
		block: block
	}
}

fn convert_parameter_list(node Node, text tree_sitter.SourceText) ParameterList {
	parameters := map_child[v.NodeType, ParameterDeclaration](node, fn [text] (n Node) ?ParameterDeclaration {
		if n.type_name == .parameter_declaration {
			return convert_parameter_declaration(n, text)
		}

		return none
	})

	return ParameterList{
		id: counter++
		node: node
		parameters: parameters
	}
}

fn convert_parameter_declaration(node Node, text tree_sitter.SourceText) ParameterDeclaration {
	// for i := u32(0); i < node.child_count(); i++ {
	// 	child := node.child(i) or { continue }
	// 	child.type_name == .triple_dot
	// }
	return ParameterDeclaration{
		id: counter++
		node: node
		name: convert_identifier(field(node, 'name'), text)
		typ: convert_type(field(node, 'type'), text)
		is_variadic: has_field(node, 'is_variadic')
	}
}

fn convert_block(node Node, text tree_sitter.SourceText) Block {
	mut stmts := []IrNode{}
	for i := u32(0); i < node.child_count(); i++ {
		child := node.child(i) or { panic("can't find #${i} node") }
		if !child.is_named() {
			continue
		}
		stmts << convert_stmt(child, text) or { continue }
	}

	return Block{
		id: counter++
		node: node
		stmts: stmts
	}
}

fn convert_stmt(node Node, text tree_sitter.SourceText) ?IrNode {
	match node.type_name {
		.simple_statement {
			return convert_simple_statement(node, text)
		}
		.assert_statement {}
		else {
			return convert_node(node, text)
		}
	}

	return none
}

fn convert_simple_statement(node Node, text tree_sitter.SourceText) SimplaStatement {
	return SimplaStatement{
		id: counter++
		node: node
		inner: convert_node(node.child(0) or { panic(err) }, text)
	}
}

fn convert_call_expression(node Node, text tree_sitter.SourceText) CallExpr {
	name := convert_identifier(field(node, 'name'), text)
	args := convert_argument_list(field(node, 'arguments'), text)

	return CallExpr{
		id: counter++
		node: node
		name: name
		args: args
	}
}

fn convert_argument_list(node Node, text tree_sitter.SourceText) ArgumentList {
	args := map_child[v.NodeType, Argument](node, fn [text] (n Node) ?Argument {
		if !n.is_named() {
			return none
		}

		return convert_argument(n, text)
	})

	return ArgumentList{
		id: counter++
		node: node
		args: args
	}
}

fn convert_argument(node Node, text tree_sitter.SourceText) Argument {
	return Argument{
		id: counter++
		node: node
		expr: convert_node(node, text) or { panic(err) }
	}
}

fn convert_type(node Node, text tree_sitter.SourceText) Type {
	match node.type_name {
		.builtin_type {
			return convert_builtin_type(node, text)
		}
		else {
			panic("can't convert type ${node.type_name}")
		}
	}
}

fn convert_builtin_type(node Node, text tree_sitter.SourceText) BuiltinType {
	return BuiltinType{
		id: counter++
		node: node
		name: node.text(text)
	}
}

fn convert_string_literal(node Node, text tree_sitter.SourceText) StringLiteral {
	return StringLiteral{
		id: counter++
		node: node
		text: node.text(text)
	}
}

fn convert_int_literal(node Node, text tree_sitter.SourceText) IntegerLiteral {
	return IntegerLiteral{
		id: counter++
		node: node
		value: node.text(text)
	}
}
