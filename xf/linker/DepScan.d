module xf.linker.DepScan;

private {
	import xf.linker.FileUtils;
	import xf.linker.ProcessUtils;

	import tango.text.Util : triml, trimr, trim;
	import tango.io.stream.Lines : LineIterator = Lines;
	import tango.io.device.File : FileConduit = File;
	import Path = tango.io.Path;
	
	import tango.util.log.Trace;
}



struct BudSettings {
	char[][]		paths;
	char[][]		exclusions;
	bool			autoImport = false;
	//char[]		cfPath = "";
	char[]		dmdPath = "";
	
	char[] toString() {
		char[] result;
		result ~= Path.native(Path.join(dmdPath, "build.exe"));
		foreach (s; paths) {
			s = trim(s);
			if (s.length > 0) {
				result ~= " -I" ~ Path.native(s);
			}
		}
		foreach (s; exclusions) {
			result ~= " -X" ~ s;
		}
		if (!autoImport) {
			result ~= " -noautoimport";
		}
		result ~= " -BCFPATH"~Path.native(dmdPath);
		result ~= " -DCPATH"~Path.native(dmdPath);
		result ~= " ";
		return result;
	}
}



void findDependencies(char[] root, char[] dfileName, BudSettings bs, bool recurse, void delegate(char[], char[]) dg) {
	scope xrefName = new TmpFile(root);
	char[] cmd = bs.toString ~ Path.native(dfileName) ~ ` -T_nothing_ -version=Tango -silent -nolink -nolib -c -o- ` ~ (recurse ? `` : `-explicit`) ~ ` -uses=` ~ Path.native(xrefName.name);
	version (LinkerSpam) Trace.formatln("depScan (root={}): {}", root, cmd);
	exec(root, cmd);
	finishCommands();

	scope xref = new FileConduit(xrefName.name, FileConduit.ReadExisting);
	scope (exit) xref.close;

	foreach (line; new LineIterator!(char)(xref)) {
		if ("[USES]" == line) {
			continue;
		} else if ("[USEDBY]" == line) {
			break;
		} else {
			foreach (i, c; line) {
				if ('<' == c && i+1 < line.length && '>' == line[i+1]) {
					dg(Path.standard(trimr(line[0..i])), Path.standard(triml(line[i+2..$])));
					break;
				}
			}
		}
	}
}
/+


void main() {
	auto bs = BudSettings(
		["../ext", "../..", "../ext/ddl"],
		["tango"]
	);
	
	findDependencies(`DepScan.d`, bs, true, (char[] uses, char[] used) {
		Trace.formatln(`'{}' uses '{}'`, uses, used);
	});
}
+/