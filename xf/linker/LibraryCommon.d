module xf.linker.LibraryCommon;

private {
	import xf.linker.ConfigUtils;
	import tango.text.Regex;
	import Path = tango.io.Path;
	import tango.text.convert.Format;
	
	import tango.util.log.Trace;
}



alias char[] LibraryType;
alias char[] LibrarySource;



struct LibLoadOptions {
	LibrarySource	root = ".";
	LibrarySource[]	includes;
}


struct LinkerSettings {
	LibrarySource	appRoot;
}


LibrarySource getSource(LibrarySource root_, LibrarySource relPath_)
out (res) {
	assert (res.length < 2 || res[$-1] != '/');
} body {
	if (0 == relPath_.length) {
		relPath_ = ".";
	}
	if (0 == root_.length) {
		root_ = ".";
	}
	auto root		= Path.standard(root_.dup);
	auto relPath	= Path.standard(relPath_.dup);
//	assert (!Path.parse(relPath).isAbsolute, "Provided path is absolute: '"~relPath~"'");
	
	void skipCur(ref char[] p) {
		if (p.length >= 2 && "./" == p[0..2]) {
			p = p[2..$];
		}
		if (p.length >= 1 && '.' == p[0]) {
			if (p.length < 2 || p[1] != '.') {
				p = p[1..$];
			}
		}
		if (p.length > 1 && '/' == p[$-1]) {
			p = p[0..$-1];
		}
	}
	
	skipCur(root);
	skipCur(relPath);
	
	while (relPath.length > 1 && relPath[0..2] == ".." && root.length > 0) {
		if (root.length >= 2 && root[$-2..$] == "..") {
			root = root ~ "/..";
		} else {
			root = Path.pop(root);
		}
		relPath = relPath[2..$];
		if (relPath.length > 0 && '/' == relPath[0]) {
			relPath = relPath[1..$];
		}
	}
	
	return Path.join(root, relPath);
}


version (XfLinkerUnitTest) static this() {
	void test(char[] root, char[] rel, char[] correct) {
		char[] got = getSource(root, rel);
		assert (got == correct, "got '" ~ got ~ "', should be: '" ~ correct ~ "' [for '" ~ root ~ "' and '" ~ rel ~ "']");
	}
	test("foo/bar", "baz", "foo/bar/baz");
	test(".", "foo", "foo");
	test("../foo/bar", "..", "../foo");
	test("foo/bar", "../baz", "foo/baz");
	test("foo/", "bar", "foo/bar");
	test("foo/", "bar/", "foo/bar");
	test("./foo/", "bar/", "foo/bar");
	test("./foo/", "./bar/", "foo/bar");
	test("foo/bar", "./x", "foo/bar/x");
	test("foo/bar", "../x", "foo/x");
	test("foo/bar", "../../x", "x");
	test("foo/bar", "../../../x", "../x");
	test("foo/bar", "../../../../x", "../../x");
	test("", "../../x", "../../x");
	test(null, "../../x", "../../x");
	test(null, "..", "..");
	test("..", "..", "../..");
	test("../", "../", "../..");
}


LibrarySource getSourceRelativeFrom(LibrarySource path_, LibrarySource root_)
out (res) {
	assert (getSource(root_, res) == path_, Format("getSource({}, {}) != '{}'", root_, res, path_));
} body {
	if (0 == path_.length) {
		path_ = ".";
	}
	if (0 == root_.length) {
		root_ = ".";
	}
	
	auto path = path_;
	auto root = root_;
	
	assert (Path.parse(root).isAbsolute);
	assert (Path.parse(path).isAbsolute);
	
	int sameTill	= 0;
	int maxLen	= path.length > root.length ? root.length : path.length;
	
	char[] res;

	while (path.length > 0) {
		char[] pathHead, pathTail, rootHead, rootTail;
		Path.split(path, pathHead, pathTail);
		Path.split(root, rootHead, rootTail);
		
		if (pathHead == rootHead) {
			path = pathTail;
			root = rootTail;
		} else {
			break;
		}
	}
	
	//Trace.formatln("unique parts: root({}) path({})", root, path);
	
	while (root.length > 0) {
		res = getSource(res, "..");
		root = Path.pop(root);
	}
	
	return getSource(res, path);
}


version (XfLinkerUnitTest) static this() {
	void test(char[] path, char[] root, char[] correct) {
		char[] got = path.getSourceRelativeFrom(root);
		assert (got == correct, "got '" ~ got ~ "', should be: '" ~ correct ~ "' [for '" ~ path ~ "' and '" ~ root ~ "']");
	}
	test("c:/foo/bar/xyz", "c:/foo/bar", "xyz");
	test("c:/foo/xyz", "c:/foo/bar", "../xyz");
	test("c:/foo", "c:/foo/bar", "..");
	test("c:/xyz", "c:/foo/bar", "../../xyz");
	test("c:", "c:/foo/bar", "../..");
}


class LibraryTypeMatcher {
	void registerRule(LibraryType type, char[] ruleName, char[] ruleCfg) {
		LibraryTypeRule rule;
		switch (ruleName) {
			case "regex": {
				rule = new RegexRule(ruleCfg);
				this.rules ~= Rule(rule, type);
			} break;
			
			default: {
				throw new Exception("Unknown library type matcher rule: '" ~ ruleName ~ "'");
			}
		}
	}
	
	
	LibraryType matchType(LibrarySource src)
	out (res) {
		assert (res.length > 0);
	} body {
		foreach (r; rules) {
			if (r.rule.matches(src)) {
				return r.type;
			}
		}
		
		throw new Exception("Could not match a library type for source: '" ~ src ~ "'");
	}
	

	void parseConfigLine(char[] line) {
		char[] type = cutOffWord(&line);
		char[] method = cutOffWord(&line);
		registerRule(type, method, line);
	}

	
	protected {
		struct Rule {
			LibraryTypeRule	rule;
			LibraryType		type;
		}
		Rule[] rules;
	}
}


abstract class LibraryTypeRule {
	bool matches(LibrarySource);
}


private final class RegexRule : LibraryTypeRule {
	this(char[] re) {
		this.regex = Regex(re);
	}
	
	
	override bool matches(LibrarySource src) {
		return regex.test(src);
	}
	
	
	Regex	regex;
}


