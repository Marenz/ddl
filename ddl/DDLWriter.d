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
	Provides Tango binary Writer support, with a few enhancements
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton
*/
module ddl.DDLWriter;

private import ddl.Utils;
private import ddl.FileBuffer;

enum Anchor{
	None,
	Begin,
	End,
	Current
}

/**
	Tango IO Writer subclass.
	
	DDLWriter, apart from adding symmetry to DDLReader, provides seeking capability for 
	random-access <i>output</i>.
*/
public class DDLWriter{
	ubyte[] data;
	uint position;
	
	/**
		IBuffer style constructor.
		
		Params:
			buffer = buffer to read
	*/
	public this (){
		position = 0;
	}
	
	public this (ubyte[] data){
		this.data = data;
		position = data.length;
	}	
	
	public this(FileBuffer buffer){
		this.data = buffer.data;
		position = 0;
	}	
	
	DDLWriter putAll(void[] x){
		ubyte[] newData = cast(ubyte[])x;
		if(position == data.length){
			data ~= newData;
			position = data.length;
		}
		else{
			data[position..position+newData.length] = newData;
		}
		return this;
	}
	
	DDLWriter put(T)(T x){
		ubyte[] newData = (cast(ubyte*)(cast(void*)&x))[0..T.sizeof];
		if(position == data.length){
			data ~= newData;
			position = data.length;
		}
		else{
			data[position..position+newData.length] = newData;
			position += newData.length;
		}
		return this;
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
	DDLWriter seek(ulong offset, Anchor anchor = Anchor.Begin){
		switch(anchor){
		case Anchor.Begin:
			assert(offset < data.length);
			position = offset;
			break;
		case Anchor.End:
			assert(data.length + offset < data.length);
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