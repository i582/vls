module ir

import tree_sitter

struct Finder {
	pos int
mut:
	found []Node = [null_node]
}

fn (mut f Finder) visit(node Node) bool {
	pos := node_pos(node)
	offset := pos.offset
	len := pos.len
	if f.pos >= offset && f.pos < offset + len {
		f.found << node
		return true
	}
	return true
}

pub fn find_element_at(node Node, pos int) Node {
	mut finder := Finder{pos: pos}
	node.accept(mut finder)

	return finder.found.last()
}

pub fn node_pos(n Node) Pos {
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

pub fn node_parent(n Node, text tree_sitter.SourceText) Node {
	parent := n.node.parent() or { return null_node }
	return convert_node(parent, text)
}
