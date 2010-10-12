/+
 compilation under Linux:
  rebuild -oqOBJS -clean -L-Map -LtestHost01.map testHost01.d
  ../Contrib/fixmap.sh testHost01.map
 +/
module host;

import xf.linker.DefaultLinker;

/*import ddl.DefaultRegistry;
import ddl.DynamicLibrary;
import ddl.Linker;
*/

import tango.io.Stdout;

import testIface01;

version(Linux) {
    static import ddl.FileBuffer;
}

int main(char[][] args) {
    auto dr = new DefaultRegistry();
    auto linker = new Linker(dr);

    Stdout("[+] supported types:").newline();
    foreach(z; dr.getSupportedTypes()) {
	Stdout.formatln ("   [*] {}", z);
    }
    Stdout.newline();

    Stdout("[+] trying to load mapfile").newline();

    auto me = linker.loadAndRegister("testHost01.map");

    if (linker.isRegistered(me)) {
	Stdout("   [*] I can has myself registered!").newline();

    } else {
	Stdout("   [!] Oh noez! I can has NOT myself registered!").newline();
    }

    Stdout("   [+] my type: " ~ me.getType()).newline();
    Stdout.newline();

    auto plugin = linker.loadLinkAndRegister("testPlug01.o");

    if (plugin is null) {
	Stdout ("failed to load plugin").newline();
	return -1;
    }

    Stdout("plugin type: " ~ plugin.getType()).newline;

    auto helloWorld = plugin.getDExport!(int function(), "testPlug01.helloWorld")();

    if (helloWorld) {
	auto z = helloWorld();
	Stdout.formatln ("result: {} ", z);

    } else {
	Stdout("couldn't resolve testPlug01.helloWorld").newline();
    }

    //
    auto testObj = plugin.getClass!(IHasFooBar, "testPlug01.Temp")().newObject!()();

    testObj.foobar();

    return 0;
}

/*
 * vim: set sts=4
 */
