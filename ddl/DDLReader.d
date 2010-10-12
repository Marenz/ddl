/+
	Copyright (c) 2006 Eric Anderton
        
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
/**
	Provides Tango binary Reader support, with a few enhancements
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton
*/
module ddl.DDLReader;

private import ddl.Utils;
private import ddl.FileBuffer;

enum Anchor{
	None,
	Begin,
	End,
	Current
}

/**
	Tango IO Reader subclass.
	
	DDLReader provides a few key pieces of functionality that are used heavily within
	DDL's input operations.  In short, it provides a way to seek, peek and get an 
	entire buffer from a buffer or condiut.  This makes it possible to implement a 
	wider array of parser types (e.g. unlimited read-ahead, and recursive descent) than
	is possible with the standard Mango Reader.
	
	The reader class itself is useful as-is, but implementors are strongly encouraged
	to subclass the reader, as to create a richer and more task-oriented feature set.
*/
public class DDLReader{
	ubyte[] data;
	size_t position;
	
	/**
		Simple constructor.
		
		Params:
			data = data to use for this reader.
	*/
	public this(void[] data){
		this.data = cast(ubyte[])data;
	}
	
	public this(FileBuffer buffer){
		this.data = buffer.data;
	}	
	
	/**
		Look ahead one byte into the input buffer, without advancing the current
		read position.
		
		Params:
			x = (inout) will contain the value of the byte just after the current read position.
	*/
    public DDLReader peek(inout ubyte x){
	    assert(this.hasMore());
		x = data[position];
        return this;
    }	
    
    /**
    	Look ahead <i>n</i> bytes into the input buffer, without advancing the current
		read position.
		
		Params:
			x = (inout) will contain the value(s) of the byte(s) just after the current read position.
			elements = (default: uint.max) the number of bytes to peek.
    */
    public DDLReader peek(inout ubyte[] x,size_t elements = size_t.max){
	    if(elements == size_t.max){
	   		x = data[position..$];
    	}
    	else{
	   		x = data[position..position+elements];
   		}
	    return this;
    }
    
    /**
    	Reads everything the underlying conduit has.  
    	
    	The current position will be at EOF after this operation.
    	
    	Params:
    		x = (inout) will contain everything from the current read position to the end of the file.
    */
	public DDLReader getAll(inout void[] x)
	{		
		x = data[position..$];
		position = data.length;		
		return this;
	}
	
	public DDLReader _get(T)(inout T x)
	{
		//debug (DDL) debugLog("reading element size: {0}",T.sizeof);
		x = *(cast(T*)(data[position..position + T.sizeof].ptr));
		position += T.sizeof;		
		return this;
	}
		
	public DDLReader get(inout char x){
		return _get(x);
	}
	
	public DDLReader get(inout wchar x){
		return _get(x);
	}
	
	public DDLReader get(inout dchar x){
		return _get(x);
	}
	
	public DDLReader get(inout byte x){
		return _get(x);
	}
	
	public DDLReader get(inout ubyte x){
		return _get(x);
	}
	
	public DDLReader get(inout short x){
		return _get(x);
	}
	
	public DDLReader get(inout ushort x){
		return _get(x);
	}	
	
	public DDLReader get(inout int x){
		return _get(x);
	}
	
	public DDLReader get(inout uint x){
		return _get(x);
	}
	
	public DDLReader get(inout long x){
		return _get(x);
	}

	public DDLReader get(inout ulong x){
		return _get(x);
	}
		
	public DDLReader _getArray(T)(inout T[] x,size_t elements = size_t.max)
	{		
		size_t end;	
	    if(elements == size_t.max){
		    //debug (DDL) debugLog("reading max");
		    end = data.length - (data.length % T.sizeof);
	   		x = cast(T[])(data[position..end]);
    	}
    	else{
	    	//debug (DDL) debugLog("size: {3} elements: {0} len: {1} pos: {2}",elements,data.length,position,T.sizeof);
	    	end = position + (elements * T.sizeof);
	   		x = cast(T[])(data[position..end]);
   		}
   		position = end;
	    return this;
	}
	
	public DDLReader get(inout char[] x,size_t elements = size_t.max){
		return _getArray!(char)(x,elements);
	}
	
	public DDLReader get(inout wchar[] x,size_t elements = size_t.max){
		return _getArray!(wchar)(x,elements);
	}
			
	public DDLReader get(inout dchar[] x,size_t elements = size_t.max){
		return _getArray!(dchar)(x,elements);
	}
	
	public DDLReader get(inout byte[] x,size_t elements = size_t.max){
		return _getArray!(byte)(x,elements);
	}
	
	public DDLReader get(inout ubyte[] x,size_t elements = size_t.max){
		return _getArray!(ubyte)(x,elements);
	}	
	
	public DDLReader get(inout short[] x,size_t elements = size_t.max){
		return _getArray!(short)(x,elements);
	}	
	
	public DDLReader get(inout ushort[] x,size_t elements = size_t.max){
		return _getArray!(ushort)(x,elements);
	}	
	
	public DDLReader get(inout int[] x,size_t elements = size_t.max){
		return _getArray!(int)(x,elements);
	}
		
	public DDLReader get(inout uint[] x,size_t elements = size_t.max){
		return _getArray!(uint)(x,elements);
	}
	
	public DDLReader get(inout long[] x,size_t elements = size_t.max){
		return _getArray!(long)(x,elements);
	}
	
	public DDLReader get(inout ulong[] x,size_t elements = size_t.max){
		return _getArray!(ulong)(x,elements);
	}		
			
	/**
		Returns: (true/false) If the conduit has any more data to be read.
	*/
	bool hasMore(){
		return position < data.length;
	}
	
	/**
		Perform a seek relative to the current buffer position and status using the conduit.
		
		Some Tango conduits are seekable directly.  For all others, this method seeks by
		manipulating the buffer and the current read position instead.
		
		<b>NOTE:</b> this will clear out the current buffer, which may have some performance 
		implications.
		
		Params:
			offset = the number of bytes to seek from the specified anchor
			anchor = (default: Begin) specifies the point in the conduit from where seeks are
			calculated (see: ISeekable.SeekAnchor for more info).
	*/
	DDLReader seek(ulong offset, Anchor anchor = Anchor.Begin){
		switch(anchor){
		case Anchor.Begin:
			assert(offset < data.length);
			position = offset;
			break;
		case Anchor.End:
			assert(position + offset < data.length);
			position = data.length + offset;
			break;
		default:
		case Anchor.None:
		case Anchor.Current:
			assert(position + offset < data.length);
			position += offset;
			break;
		}
		return this;
	}
	
	/**
		Returns: The position relative to the current buffer position.
	*/
	size_t getPosition(){
		return position;
	}
	
	ubyte[] getData(){
		return data;
	}
}
