/+
 compilation under Linux:
  rebuild -oqOBJS -clean -L-Map -LtestHost02.map testHost02.d
  ../Contrib/fixmap.sh testHost02.map
 +/
module host2;

import ddl.DefaultRegistry;
import ddl.DynamicLibrary;
import ddl.Linker;

import tango.io.Stdout;

version(Linux) {
    static import ddl.FileBuffer;
}

extern(C) {
    int i; // variable accessible by C-style-plugin
}

int main(char[][] args) {
    auto dr = new DefaultRegistry();
    auto linker = new Linker(dr);

    Stdout("[+] trying to load mapfile").newline();
    auto me = linker.loadAndRegister("testHost02.map");

    if (!linker.isRegistered(me)) {
	Stdout("   [!] Oh noez! I can has NOT myself registered!").newline();
	return 1;
    }

    auto plugin = linker.loadLinkAndRegister("testPlug02_c.o");
    if (plugin is null) {
	Stdout ("failed to load plugin").newline();
	return -1;
    }

    Stdout("plugin type: " ~ plugin.getType()).newline;

    i = 7;

    auto t = cast(int function())(plugin.getSymbol("blurp").address);
    Stdout ( t() ).newline; // should print 1346
    Stdout ( i ).newline; // should equal 673

    return 0;
}

/*
 * vim: set sts=4
 */
