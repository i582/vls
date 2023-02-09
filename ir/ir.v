module ir

import tree_sitter
import tree_sitter_v as v

struct Pos {
pub:
	offset u32
	len    u32
	start  Point
	end    Point
}

struct Point {
pub:
	line u32
	col  u32
}

type Node = tree_sitter.Node[v.NodeType]

pub type ID = int

pub const null_node = NullNode{}

pub interface IrNode {
	id ID
	node Node
	accept(mut v Visitor) bool
}

pub interface Stmt {
	stmt()
}

pub struct NullNode {
pub:
	id   ID = -1
	node Node
}

fn (n NullNode) accept(mut visitor Visitor) bool {
	return visitor.visit(n)
}

pub struct File {
pub:
	tree          tree_sitter.Tree[v.NodeType]
	id            ID
	node          Node
	module_clause IrNode
	imports       ImportList
	stmts         []IrNode
}

pub fn (f File) accept(mut visitor Visitor) bool {
	if !visitor.visit(f) {
		return false
	}

	if !f.module_clause.accept(mut visitor) {
		return false
	}

	if !f.imports.accept(mut visitor) {
		return false
	}

	for stmt in f.stmts {
		if !stmt.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct ModuleClause {
pub:
	id   ID
	node Node
	name Identifier
}

fn (m ModuleClause) accept(mut visitor Visitor) bool {
	if !visitor.visit(m) {
		return false
	}

	if !m.name.accept(mut visitor) {
		return false
	}

	return true
}

pub struct ImportList {
pub:
	id      ID
	node    Node
	imports []ImportDeclaration
}

fn (i ImportList) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	for imp in i.imports {
		if !imp.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct ImportDeclaration {
pub:
	id   ID
	node Node
	spec ImportSpec
}

fn (i ImportDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	if !i.spec.accept(mut visitor) {
		return false
	}

	return true
}

pub struct ImportSpec {
pub:
	id    ID
	node  Node
	path  ImportPath
	alias IrNode
}

fn (i ImportSpec) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	if !i.path.accept(mut visitor) {
		return false
	}

	if !i.alias.accept(mut visitor) {
		return false
	}

	return true
}

pub struct ImportPath {
pub:
	id    ID
	node  Node
	value string
}

fn (i ImportPath) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct ImportAlias {
pub:
	id   ID
	node Node
	name string
}

fn (i ImportAlias) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct Identifier {
pub:
	id    ID
	node  Node
	value string
}

fn (i Identifier) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct FunctionDeclaration {
pub:
	id         ID
	node       Node
	name       Identifier
	parameters ParameterList
	block      Block
}

fn (f FunctionDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(f) {
		return false
	}

	if !f.name.accept(mut visitor) {
		return false
	}

	if !f.parameters.accept(mut visitor) {
		return false
	}

	if !f.block.accept(mut visitor) {
		return false
	}

	return true
}

pub struct ParameterList {
pub:
	id         ID
	node       Node
	parameters []ParameterDeclaration
}

fn (p ParameterList) accept(mut visitor Visitor) bool {
	if !visitor.visit(p) {
		return false
	}

	for param in p.parameters {
		if !param.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct ParameterDeclaration {
pub:
	id          ID
	node        Node
	name        Identifier
	typ         Type
	is_variadic bool
}

fn (p ParameterDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(p) {
		return false
	}

	if !p.name.accept(mut visitor) {
		return false
	}

	if !p.typ.accept(mut visitor) {
		return false
	}

	return true
}

pub struct Block {
pub:
	id    ID
	node  Node
	stmts []IrNode
}

fn (b Block) accept(mut visitor Visitor) bool {
	if !visitor.visit(b) {
		return false
	}

	for stmt in b.stmts {
		if !stmt.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct SimplaStatement {
pub:
	id    ID
	node  Node
	inner ?IrNode
}

fn (s SimplaStatement) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	if s.inner or { return true }.accept(mut visitor) {
		return false
	}

	return true
}

fn (_ SimplaStatement) stmt() {}

pub struct CallExpr {
pub:
	id   ID
	node Node
	name Identifier
	args ArgumentList
}

fn (c CallExpr) accept(mut visitor Visitor) bool {
	if !visitor.visit(c) {
		return false
	}

	if !c.name.accept(mut visitor) {
		return false
	}

	if !c.args.accept(mut visitor) {
		return false
	}

	return true
}

pub struct ArgumentList {
pub:
	id   ID
	node Node
	args []Argument
}

fn (a ArgumentList) accept(mut visitor Visitor) bool {
	if !visitor.visit(a) {
		return false
	}

	for arg in a.args {
		if !arg.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct Argument {
pub:
	id   ID
	node Node
	expr IrNode
}

fn (a Argument) accept(mut visitor Visitor) bool {
	if !visitor.visit(a) {
		return false
	}

	if !a.expr.accept(mut visitor) {
		return false
	}

	return true
}

interface Type {
	IrNode
	typ()
	readable_name() string
}

pub struct BuiltinType {
pub:
	id   ID
	node Node
	name string
}

fn (s BuiltinType) typ() {}

fn (s BuiltinType) readable_name() string {
	return s.name
}

fn (s BuiltinType) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	return true
}

pub struct SimpleType {
pub:
	id   ID
	node Node
	name Identifier
}

fn (s SimpleType) typ() {}

fn (s SimpleType) readable_name() string {
	return s.name.value
}

fn (s SimpleType) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	if !s.name.accept(mut visitor) {
		return false
	}

	return true
}

pub struct StringLiteral {
pub:
	id   ID
	node Node
	text string
}

fn (s StringLiteral) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	return true
}

pub struct IntegerLiteral {
pub:
	id    ID
	node  Node
	value string
}

fn (i IntegerLiteral) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	return true
}
