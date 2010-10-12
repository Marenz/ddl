/+
	Copyright (c) 2005-2007 Eric Anderton
        
	Permission is hereby granted, free of charge, to any person
	obtaining a copy of this software and associated documentation
	files (the "Software"), to deal in the Software without
	restriction, including without limitation the rights to use,
	copy, modify, merge, publish, distribute, sublicense, and/or
	sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following
	conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
	OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
	HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
	OTHER DEALINGS IN THE SOFTWARE.
+/
module ddl.Utils;

//private import tango.text.convert.Sprint;
private import tango.text.convert.Format;
    
//TODO: this is a stub for mango-tango conversion - remove me
//alias Sprint!(char) ExtSprintClass;

size_t indexOf(T)(T[] str,T find){
	foreach(idx,ch; str){
		if(ch == find) return idx;
	}
	return str.length;
}

char[] dataDumper(void* data,uint length){
	char[] result = "";
	char[] buf2 = "";
	ubyte* ptr = cast(ubyte*)(cast(uint)data&0xFFFFFFF0); // start at nearest page
	//ExtSprintClass sprint = new ExtSprintClass(1024);
	
	for(uint idx=0; idx<length; idx++,ptr++){
		ubyte b = *ptr;
		if(idx % 16 == 0){
			 result ~= Format(" |  {0}\n  [{1:8X}] ",buf2,ptr);
			 buf2 = "";
		}
		
		if(ptr == data){
			result ~= "*";
		}
		else{
			result ~= " ";
		}
		
		if(b < 16) result ~= "0"; //HACK: sprint doesn't left-pad correctly
		result ~= Format("%0.2X",b);
				
		if(b >= 32 && b <= 126){
			buf2 ~= cast(char)b;
		}
		else{
			buf2 ~= ".";
		}
	}
	result ~= " | " ~ buf2 ~ "\n";	
	return result;
}

/*
debug{   
	private import mango.log.Logger;
	private import mango.log.DateLayout;
	
	Logger ddlLog;
	
	static this(){
		ddlLog = Logger.getLogger("ddl.logger");
		ddlLog.info("Logger Initalized");
		ddlLog.
	}
	
	public void debugLog(...){
		
	}
}*/
debug{	
	private import tango.io.Stdout;
	public void debugLog(V...)(char[] s,V args){
		Stdout.formatln(s,args);
		Stdout.flush();
	}	
}

unittest{}
