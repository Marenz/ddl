/+
	Copyright (c) 2005-2007 J Duncan, Eric Anderton
        
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

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/
module ddl.coff.cursor;

import ddl.coff.COFFReader;

//import dmddebug.cv4;		// codeview 4 api
//import dmddebug.coffimage;	// coff dll/exe image module
//import dmddebug.demangle;	// mangle/demangle identifier names
//import dmddebug.symbols;	// symbols management header

private import std.stdio;
private import std.string;
private import std.file;
private import std.stream;
//private import windows.winnt;

struct DataCursor
{
	public char[] data;
	public uint position;

	public char getNext()
	{
		assert( hasMore );
		char ch = data[position];
		position++;
		return ch;
	}

	public char peek()
	{
		return data[position];
	}

	public void unget()
	{
		position--;
	}

	// attempt to parse a string token
	public bool parseToken(char[] test)
	{
		if( test.length > data.length - position )
			return false;

		if(data[position..position+test.length] == test[0..$])
		{
			position += test.length;
			return true;
		}
		return false;
	}

	// primitive type parsing
	public int parseBYTE()
	{
		assert( data.length - position >= byte.sizeof );
		byte val = *cast(byte*)(data.ptr + position);
		position += byte.sizeof;
		return val;
	}

	public int parseUBYTE()
	{
		assert( data.length - position >= ubyte.sizeof );
		ubyte val = *cast(ubyte*)(data.ptr + position);
		position += ubyte.sizeof;
		return val;
	}

	public int parseSHORT()
	{
		assert( data.length - position >= short.sizeof );
		short val = *cast(short*)(data.ptr + position);
		position += short.sizeof;
		return val;
	}

	public int parseUSHORT()
	{
		assert( data.length - position >= ushort.sizeof );
		ushort val = *cast(ushort*)(data.ptr + position);
		position += ushort.sizeof;
		return val;
	}

	public int parseINT()
	{
		assert( data.length - position >= int.sizeof );
		int val = *cast(int*)(data.ptr + position);
		position += int.sizeof;
		return val;
	}

	public uint parseUINT()
	{
		assert( data.length - position >= uint.sizeof );
		uint val = *cast(uint*)(data.ptr + position);
		position += uint.sizeof;
		return val;
	}

	public uint parseInteger()
	{
		uint value;
		char ch;
		while(nextIsDigit())
		{
			ch = getNext();
			value = (value * 10) + cast(uint)(ch - '0');
		}
		return value;
	}

	public char[] parseIntegerString()
	{
		uint start = position;
		while(hasMore() && nextIsDigit())
		{
			position++;
		}
		return data[start..position];
	}

	public char[] parseString(uint len)
	{
		char[] value = data[position..position+len];
		position += len;
		return value;
	}

	public bool nextIsDigit()
	{
		char ch = data[position];
		return ch >= '0' && ch <= '9';
	}
	
	public char* ptr()
	{
		return data.ptr + position;
	}

	public bool hasMore()				{ return position < data.length;	}

	public char[] getRemaining()		{ return data[position..$];			}

	public uint length()				{ return data.length-position;		}

	public bool parseExact(char[] test)	{ return (length == test.length) && parseToken(test);	}

	// create a sub-cursor
	public DataCursor cursor( uint len )
	{
		DataCursor cur;
		cur.data = data[ position..position+len];
		return cur;
	}

}

