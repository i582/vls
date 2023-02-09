module ir

import tree_sitter

struct Finder {
	pos int
mut:
	found []IrNode = [null_node]
}

fn (mut f Finder) visit(node IrNode) bool {
	pos := node_pos(node)
	offset := pos.offset
	len := pos.len
	if f.pos >= offset && f.pos < offset + len {
		f.found << node
		return true
	}
	return true
}

pub fn find_element_at(node IrNode, pos int) IrNode {
	mut finder := Finder{pos: pos}
	node.accept(mut finder)

	return finder.found.last()
}

pub fn node_pos(n IrNode) Pos {
	start := n.node.start_point()
	end := n.node.end_point()
	return Pos{
		offset: n.node.start_byte()
		len: n.node.end_byte() - n.node.start_byte()
		start: Point{
			line: start.row
			col: start.column
		}
		end: Point{
			line: end.row
			col: end.column
		}
	}
}

pub fn node_parent(n IrNode, text tree_sitter.SourceText) IrNode {
	parent := n.node.parent() or { return null_node }
	return convert_node(parent, text) or { return null_node }
}
