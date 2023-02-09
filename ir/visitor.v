module ir

pub interface Visitor {
mut:
	visit(node IrNode) bool
}
