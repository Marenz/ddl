/+
	Copyright (c) 2005 Eric Anderton
        
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
module ddl.FileBuffer;

private import tango.io.FilePath;
private import tango.io.device.File;

struct FileBuffer{
	FilePath path;
	ubyte[] data;
		
	static FileBuffer opCall(char[] path){
		FileBuffer _this;
		_this.path = new FilePath(path);		
		_this.data = cast(ubyte[])File.get(_this.path.toString);
		return _this;
	}
	
	static FileBuffer opCall(FilePath path){
		FileBuffer _this;
		_this.path = new FilePath(path.toString);		
		_this.data = cast(ubyte[])File.get(_this.path.toString);
		return _this;
	}
	
	static FileBuffer opCall(char[] path,ubyte[] data){
		FileBuffer _this;
		_this.path = FilePath(path);		
		_this.data = data;
		return _this;
	}	
	
	static FileBuffer opCall(FilePath path,ubyte[] data){
		FileBuffer _this;
		_this.path = FilePath(path.toString);		
		_this.data = data;
		return _this;
	}
	
	FilePath getPath(){
		return path;
	}
	
	void save(){
		File.set(this.path.toString, this.data);
	}
	
	void deleteData() {
		delete this.data;
	}
}
