module parser

import ir
import tree_sitter_v as v
import tree_sitter
import structures.ropes
import io
import os

// Source represent the possible types of V source code to parse.
type Source = []byte | io.Reader | string

// parse_file parses a V source file and returns the corresponding `ir.File` node.
// If the file could not be read, an error is returned.
// If the file was read successfully, but could not be parsed, the result
// is a partiall AST.
//
// Example:
// ```
// import parser
//
// fn main() {
//   mut file := parser.parse_file('foo.v') or {
//     eprintln('Error: could not parse file: ${err}')
//     return
//   }
//   println(file)
// }
// ```
pub fn parse_file(filename string) !ir.File {
	mut file := os.read_file(filename, 'r', 0) or {
		return error('could not read file ${filename}: ${err}')
	}
	return parse_source(file)
}

// parse_source parses a V code and returns the corresponding `ir.File` node.
// Unlike `parse_file`, `parse_source` uses the source directly, without reading it from a file.
// See `parser.Source` for the possible types of `source`.
//
// Example:
// ```
// import parser
//
// fn main() {
//   mut file := parser.parse_source('fn main() { println("Hello, World!") }') or {
//     eprintln('Error: could not parse source: ${err}')
//     return
//   }
//   println(file)
// }
// ```
pub fn parse_source(source Source) !ir.File {
	code := match source {
		string {
			source
		}
		io.Reader {
			io.read_all(reader: source) or {
				eprintln('Error: could not read from reader')
				return error('could not read from reader')
			}
		}
		[]byte {
			source.str()
		}
	}
	return parse_code(code)
}

// parse_code parses a V code and returns the corresponding ir.File node.
// Unlike `parse_file` and `parse_source`, `parse_code` don't return an error since
// the source is always valid.
pub fn parse_code(code string) ir.File {
	rope := ropes.new(code)
	mut parser := tree_sitter.new_parser[v.NodeType](v.language, v.type_factory)
	tree := parser.parse_string(source: code)
	return ir.convert_file(tree, tree.root_node(), rope)
}
