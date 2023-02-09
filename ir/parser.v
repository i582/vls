module ir

import tree_sitter_v as v
import tree_sitter

pub fn new_parser() &tree_sitter.Parser[v.NodeType] {
	return tree_sitter.new_parser[v.NodeType](v.language, v.type_factory)
}
