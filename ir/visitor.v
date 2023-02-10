module ir

pub interface Visitor {
mut:
	visit(node Node) bool
}
