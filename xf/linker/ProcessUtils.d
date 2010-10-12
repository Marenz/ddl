module xf.linker.ProcessUtils;

private {
	import tango.io.stream.Lines : LineIterator = Lines;
	import tango.text.Util : trim;
	import tango.sys.Process;
	import tango.sys.Environment;
	import tango.io.Stdout;
	import tango.stdc.stdio : getchar;
}



Process[] commands;

void exec(char[] wdir, char[] cmd) {
	auto proc = new Process(false, cmd);
	proc.workDir = wdir;
	(commands ~= (proc))[$-1].execute();
}

void finishCommands() {
	static int lineNo;
	
	foreach (ref p; commands) {
		p.stdout.close;
		foreach (it; new LineIterator!(char)(p.stderr)) {
			++lineNo;
			/+if (0 == lineNo % 24) {
				Stdout.formatln(`Press ENTER for more`\n);
				getchar();
			}+/
			/+version (LinkerSpam) +/if (it.trim().length > 0) Stdout(it).newline;
		}
		p.wait();
	}
	commands.length = 0;
}
