/+
 compilation:
 dmd -c testPlug01.d
 +/

module testPlug01;

import tango.io.Stdout;

import testIface01;

int helloWorld(){
	Stdout("hello world from plugin").newline();
	return 666;
}

class Temp : IHasFooBar {
public:
    this () { }

    void foobar() {
	Stdout ("in foobar() in instance of Temp").newline();
    }
}
