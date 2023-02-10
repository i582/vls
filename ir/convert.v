module ir

import tree_sitter
import tree_sitter_v as v

__global counter = 0

pub fn convert_file(tree tree_sitter.Tree[v.NodeType], node TSNode, text tree_sitter.SourceText) File {
	module_clause := field_opt(node, 'module_clause') or { TSNode{} }

	stmts_node := field(node, 'stmts')

	mut stmts := []Node{}
	mut sibling := stmts_node
	for {
		stmts << convert_stmt(sibling, text) or { continue }
		sibling = sibling.next_sibling() or { break }
	}

	return File{
		id: counter++
		tree: tree
		node: node
		module_clause: convert_node(module_clause, text)
		imports: convert_import_list(node, text)
		stmts: stmts
	}
}

fn convert_module_clause(node TSNode, text tree_sitter.SourceText) ModuleClause {
	return ModuleClause{
		id: counter++
		node: node
		name: convert_identifier(field_id(node, 0), text)
	}
}

fn convert_import_list(node TSNode, text tree_sitter.SourceText) ImportList {
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

fn convert_import_declaration(node TSNode, text tree_sitter.SourceText) ImportDeclaration {
	return ImportDeclaration{
		id: counter++
		node: node
		spec: convert_import_spec(node, text)
	}
}

fn convert_import_spec(node TSNode, text tree_sitter.SourceText) ImportSpec {
	path := field(node, 'import_path')
	alias := field_opt(node, 'import_alias') or { TSNode{} }
	return ImportSpec{
		id: counter++
		node: node
		path: convert_import_path(path, text)
		alias: convert_import_alias(alias, text) or { Node(null_node) }
	}
}

fn convert_import_path(node TSNode, text tree_sitter.SourceText) ImportPath {
	return ImportPath{
		id: counter++
		node: node
		value: node.text(text)
	}
}

fn convert_import_alias(node TSNode, text tree_sitter.SourceText) ?Node {
	if node == TSNode{} {
		return none
	}
	name := field_opt(node, 'name')?
	return ImportAlias{
		id: counter++
		node: node
		name: name.text(text)
	}
}

fn convert_struct_declaration(node TSNode, text tree_sitter.SourceText) StructDeclaration {
	return StructDeclaration{
		id: counter++
		node: node
		name: convert_identifier(field(node, 'name'), text)
		groups: convert_fields_groups(field_opt(node, 'fields_groups') or { TSNode{} },
			text)
	}
}

fn convert_fields_groups(node TSNode, text tree_sitter.SourceText) []StructFieldsGroup {
	if node.type_name == .unknown {
		return []
	}

	mut groups := []StructFieldsGroup{}
	mut sibling := node
	for {
		groups << convert_struct_fields_group(sibling, text)
		sibling = sibling.next_sibling() or { break }
	}
	return groups
}

fn convert_struct_fields_group(node TSNode, text tree_sitter.SourceText) StructFieldsGroup {
	return StructFieldsGroup{
		id: counter++
		node: node
		fields_: convert_struct_fields(node, text)
	}
}

fn convert_struct_fields(node TSNode, text tree_sitter.SourceText) []FieldDeclaration {
	mut fields := []FieldDeclaration{}
	mut sibling := node
	for {
		if sibling.is_named() {
			fields << convert_field_declaration(sibling, text)
		}
		sibling = sibling.next_sibling() or { break }
	}
	return fields
}

fn convert_field_declaration(node TSNode, text tree_sitter.SourceText) FieldDeclaration {
	return FieldDeclaration{
		id: counter++
		node: node
		name: convert_identifier(field(node, 'name'), text)
		typ: convert_type(field(node, 'type'), text)
		default_value: convert_node(field_opt(node, 'default_value') or { TSNode{} },
			text)
	}
}

fn convert_node_field(node TSNode, field_name string, text tree_sitter.SourceText) Node {
	field := field_opt(node, field_name) or { return Node(null_node) }
	return convert_node(field, text)
}

fn convert_node(node TSNode, text tree_sitter.SourceText) Node {
	match node.type_name {
		.block {
			return convert_block(node, text)
		}
		.identifier {
			return convert_identifier(node, text)
		}
		.call_expression {
			return convert_call_expression(node, text)
		}
		.interpreted_string_literal {
			return convert_string_literal(node, text)
		}
		.literal {
			return convert_literal(node, text)
		}
		.function_declaration {
			return convert_function_declaration(node, text)
		}
		.parameter_declaration {
			return convert_parameter_declaration(node, text)
		}
		.struct_declaration {
			return convert_struct_declaration(node, text)
		}
		.module_clause {
			return convert_module_clause(node, text)
		}
		.if_expression {
			return convert_if_expression(node, text)
		}
		else {
			return null_node
		}
	}
}

fn field(node TSNode, name string) TSNode {
	return node.child_by_field_name(name) or { panic(err) }
}

fn field_opt(node TSNode, name string) ?tree_sitter.Node[v.NodeType] {
	return node.child_by_field_name(name)
}

fn field_id(node TSNode, id u32) TSNode {
	return node.child(id) or { panic(err) }
}

fn has_field(node TSNode, name string) bool {
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

fn convert_identifier(node TSNode, text tree_sitter.SourceText) Identifier {
	return Identifier{
		id: counter++
		node: node
		value: node.text(text)
	}
}

fn convert_if_expression(node TSNode, text tree_sitter.SourceText) IfExpression {
	return IfExpression{
		id: counter++
		node: node
		condition: convert_node_field(node, 'condition', text)
		guard: convert_node_field(node, 'guard', text)
		block: convert_node_field(node, 'block', text)
		else_branch: convert_node_field(node, 'else_branch', text)
	}
}

pub fn convert_function_declaration(node TSNode, text tree_sitter.SourceText) FunctionDeclaration {
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

fn convert_parameter_list(node TSNode, text tree_sitter.SourceText) ParameterList {
	parameters := map_child[v.NodeType, ParameterDeclaration](node, fn [text] (n TSNode) ?ParameterDeclaration {
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

fn convert_parameter_declaration(node TSNode, text tree_sitter.SourceText) ParameterDeclaration {
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

fn convert_block(node TSNode, text tree_sitter.SourceText) Block {
	mut stmts := []Node{}
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

fn convert_stmt(node TSNode, text tree_sitter.SourceText) ?Node {
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

fn convert_simple_statement(node TSNode, text tree_sitter.SourceText) SimplaStatement {
	return SimplaStatement{
		id: counter++
		node: node
		inner: convert_node(node.child(0) or { panic(err) }, text)
	}
}

fn convert_call_expression(node TSNode, text tree_sitter.SourceText) CallExpr {
	name := convert_identifier(field(node, 'name'), text)
	args := convert_argument_list(field(node, 'arguments'), text)

	return CallExpr{
		id: counter++
		node: node
		name: name
		args: args
	}
}

fn convert_argument_list(node TSNode, text tree_sitter.SourceText) ArgumentList {
	args := map_child[v.NodeType, Argument](node, fn [text] (n TSNode) ?Argument {
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

fn convert_argument(node TSNode, text tree_sitter.SourceText) Argument {
	return Argument{
		id: counter++
		node: node
		expr: convert_node(node, text)
	}
}

fn convert_type(node TSNode, text tree_sitter.SourceText) Type {
	match node.type_name {
		.builtin_type {
			return convert_builtin_type(node, text)
		}
		else {
			panic("can't convert type ${node.type_name}")
		}
	}
}

fn convert_builtin_type(node TSNode, text tree_sitter.SourceText) BuiltinType {
	return BuiltinType{
		id: counter++
		node: node
		name: node.text(text)
	}
}

fn convert_string_literal(node TSNode, text tree_sitter.SourceText) StringLiteral {
	return StringLiteral{
		id: counter++
		node: node
		text: node.text(text)
	}
}

fn convert_int_literal(node TSNode, text tree_sitter.SourceText) IntegerLiteral {
	return IntegerLiteral{
		id: counter++
		node: node
		value: node.text(text)
	}
}

fn convert_boolean_literal(node TSNode, text tree_sitter.SourceText) BooleanLiteral {
	return BooleanLiteral{
		id: counter++
		node: node
		value: node.text(text).bool()
	}
}

fn convert_none_literal(node TSNode, text tree_sitter.SourceText) NoneLiteral {
	return NoneLiteral{
		id: counter++
		node: node
	}
}

fn convert_literal(node TSNode, text tree_sitter.SourceText) Node {
	inner := field_id(node, 0)
	match inner.type_name {
		.interpreted_string_literal {
			return convert_string_literal(node, text)
		}
		.int_literal {
			return convert_int_literal(node, text)
		}
		.true_, .false_ {
			return convert_boolean_literal(node, text)
		}
		.none_ {
			return convert_none_literal(node, text)
		}
		else {
			return null_node
		}
	}
}
