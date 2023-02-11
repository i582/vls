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

type TSNode = tree_sitter.Node[v.NodeType]

pub type ID = int

pub const null_node = NullNode{}

pub interface Node {
	id ID
	node TSNode
	accept(mut v Visitor) bool
}

pub interface Stmt {
	stmt()
}

pub struct NullNode {
pub:
	id   ID = -1
	node TSNode
}

fn (n NullNode) accept(mut visitor Visitor) bool {
	return visitor.visit(n)
}

fn (n NullNode) str() string {
	return 'null'
}

fn (n NullNode) == (other NullNode) bool {
	return true
}

pub struct File {
pub:
	id            ID
	node          TSNode
	module_clause Node
	imports       ImportList
	stmts         []Node
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
	node TSNode
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
	node    TSNode
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
	node TSNode
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
	node  TSNode
	path  ImportPath
	alias Node
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
	node  TSNode
	value string
}

fn (i ImportPath) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct ImportAlias {
pub:
	id   ID
	node TSNode
	name string
}

fn (i ImportAlias) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct StructDeclaration {
pub:
	id     ID
	node   TSNode
	name   Identifier
	groups []StructFieldsGroup
}

fn (s StructDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	if !s.name.accept(mut visitor) {
		return false
	}

	for group in s.groups {
		if !group.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct StructFieldsGroup {
pub:
	id      ID
	node    TSNode
	fields_ []FieldDeclaration
}

fn (s StructFieldsGroup) accept(mut visitor Visitor) bool {
	if !visitor.visit(s) {
		return false
	}

	for field in s.fields_ {
		if !field.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct FieldDeclaration {
pub:
	id            ID
	node          TSNode
	name          Identifier
	typ           Type
	default_value Node // DefaultValue
}

fn (f FieldDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(f) {
		return false
	}

	if !f.name.accept(mut visitor) {
		return false
	}

	if !f.typ.accept(mut visitor) {
		return false
	}

	if !f.default_value.accept(mut visitor) {
		return false
	}

	return true
}

pub struct DefaultValue {
pub:
	id   ID
	node TSNode
	expr Node
}

fn (d DefaultValue) accept(mut visitor Visitor) bool {
	if !visitor.visit(d) {
		return false
	}

	if !d.expr.accept(mut visitor) {
		return false
	}

	return true
}

// Expressions

pub struct ExpressionList {
pub:
	id    ID
	node  TSNode
	expressions []Node
}

fn (e ExpressionList) accept(mut visitor Visitor) bool {
	if !visitor.visit(e) {
		return false
	}

	for expr in e.expressions {
		if !expr.accept(mut visitor) {
			return false
		}
	}

	return true
}

pub struct IfExpression {
pub:
	id          ID
	node        TSNode
	condition   Node
	guard       Node // VarDeclaration or null_node
	block       Node
	else_branch Node // IfExpression or block or null_node
}

fn (i IfExpression) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	if !i.condition.accept(mut visitor) {
		return false
	}

	if !i.guard.accept(mut visitor) {
		return false
	}

	if !i.block.accept(mut visitor) {
		return false
	}

	if !i.else_branch.accept(mut visitor) {
		return false
	}

	return true
}

// Declarations

pub struct VarDeclaration {
pub:
	id              ID
	node            TSNode
	var_list        ExpressionList
	expression_list ExpressionList
}

fn (var VarDeclaration) accept(mut visitor Visitor) bool {
	if !visitor.visit(var) {
		return false
	}

	if !var.var_list.accept(mut visitor) {
		return false
	}

	if !var.expression_list.accept(mut visitor) {
		return false
	}

	return true
}

pub struct Identifier {
pub:
	id    ID
	node  TSNode
	value string
}

fn (i Identifier) accept(mut visitor Visitor) bool {
	return visitor.visit(i)
}

pub struct FunctionDeclaration {
pub:
	id         ID
	node       TSNode
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
	node       TSNode
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
	node        TSNode
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
	node  TSNode
	stmts []Node
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
	node  TSNode
	inner ?Node
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
	node TSNode
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
	node TSNode
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
	node TSNode
	expr Node
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
	Node
	typ()
	readable_name() string
}

pub struct BuiltinType {
pub:
	id   ID
	node TSNode
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
	node TSNode
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
	node TSNode
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
	node  TSNode
	value string
}

fn (i IntegerLiteral) accept(mut visitor Visitor) bool {
	if !visitor.visit(i) {
		return false
	}

	return true
}

pub struct BooleanLiteral {
pub:
	id    ID
	node  TSNode
	value bool
}

fn (b BooleanLiteral) accept(mut visitor Visitor) bool {
	if !visitor.visit(b) {
		return false
	}

	return true
}

pub struct NoneLiteral {
pub:
	id   ID
	node TSNode
}

fn (n NoneLiteral) accept(mut visitor Visitor) bool {
	if !visitor.visit(n) {
		return false
	}

	return true
}
