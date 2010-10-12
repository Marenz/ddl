module xf.linker.Compiler;

private {
	import xf.linker.ProcessUtils;
	import Path = tango.io.Path;
	alias Path.parse parsePath;
	
	import tango.text.Util : trim;
	import tango.util.log.Trace;
}



struct CompilerOptions {
	bool			release = false;
	bool			inline = false;
	bool			optimize = false;
	bool			debugSymbols = true;
	char[][]		importPaths;
	char[][]		versions;
	
	char[] toString() {
		char[] res;
		foreach (path; importPaths) {
			path = trim(path);
			if (path.length > 0) {
				res ~= " -I" ~ path;
			}
		}
		if (release) {
			res ~= " -release";
		}
		if (inline) {
			res ~= " -inline";
		}
		if (optimize) {
			res ~= " -O";
		}
		if (debugSymbols) {
			res ~= " -g";
		}
		foreach (v; versions) {
			res ~= " -version=" ~ v;
		}
		return res;
	}
}


class Compiler {
	CompilerOptions	options;
	char[]					dmdPath;
	
	
	// modulePath is relative to the rootDir
	void compile(char[] rootDir, char[] modulePath, char[] objPath) {
		// compile just the one module, without caring about deps
		char[] cmd = command(modulePath, objPath);
		version (LinkerSpam) Trace.formatln("Compiler: {}", cmd);
		exec(rootDir, cmd);
	}
	
	
	protected {
		char[] command(char[] modulePath, char[] objPath_) {
			char[] res = _executable;
			res ~= " -c ";
			res ~= options.toString;
			res ~= " ";
			res ~= modulePath;			
			
			auto objPath = parsePath(objPath_);
			res ~= " -od" ~ objPath.parent;
			res ~= " -of" ~ objPath.file;
			
			return res;
		}
		
		
		char[] _executable() {
			return Path.join(dmdPath, "dmd.exe");
		}
	}
}
