/+
 compilation under Linux:
  rebuild -oqOBJS -clean -L-Map -Ltest01.map -L-lc -L-d testReflection01.d
  ../Contrib/fixmap.sh test01.map
 +/
module testReflection01;

import ddl.DefaultRegistry;
import ddl.DynamicLibrary;
import ddl.Linker;

import tango.io.Stdout;

version(Linux)
{
    static import ddl.FileBuffer;
}

class Foo
{
    static void bar()
    {
	Stdout("testReflection01.Foo.bar(): in bar").newline();
    }

    this() { }
    this (int x)
    {
	Stdout("int ctor").newline();
    }

    void foobar()
    {
	Stdout("oh hi").newline();
    }
}

void baz()
{
    Stdout("testReflection01.baz(): in baz").newline();
}

int main(char[][] args)
{
    auto dr = new DefaultRegistry();
    auto linker = new Linker(dr);


    Stdout("[+] trying to load mapfile").newline();
    auto me = linker.loadAndRegister("test01.map");

    if (linker.isRegistered(me)) {
	Stdout("   [*] I can has myself registered!").newline();

    } else {
	Stdout("   [!] Oh noez! I can has NOT myself registered!").newline();
	return -1;
    }

    Stdout ("[+] Trying to call static method testReflection01.Foo.bar() via reflection").newline();
    auto f1 = me.getDExport!(void function(), "testReflection01.Foo.bar")();
    if (f1 !is null) {
	f1();

    } else {
	Stdout ("[!] Couldn't find ;(").newline();
    }

    Stdout ("[+] Trying to call module level function testReflection01.baz() via reflection").newline();	
    auto f2 = me.getDExport!(void function(), "testReflection01.baz")();
    if (f2 !is null) {
	f2();

    } else {
	Stdout ("[!] Couldn't find ;(").newline();
    }

    Stdout ("[+] Trying to get testReflection01.Foo obj via reflection").newline();
    auto meClass = me.getClass!(Object, "testReflection01.Foo")();

    Stdout ("[+] Trying to get default testReflection01.Foo ctor via reflection").newline();
    auto fooObject2 = meClass.newObject!(int)(10);
    Stdout.formatln("   [*] Instantion of: {}", fooObject2);

    Stdout ("[+] Trying to get (int) testReflection01.Foo ctor via reflection").newline();
    try {
	auto fooObject1 = meClass.newObject!()();
	Stdout.formatln("   [*] Instantion of: {}", fooObject1);

    } catch (Exception e) {
	Stdout("   [!] exception: ", e).newline();
    }

    return 0;
}

/*
 * vim: set sts=4
 */
