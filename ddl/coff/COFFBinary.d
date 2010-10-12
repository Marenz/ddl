/+
	Copyright (c) 2005-2007  J Duncan, Eric Anderton
        
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
	Windows PE-COFF binary base class for .obj, .exe, and .dll files

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFBinary;

import ddl.coff.COFF;
import ddl.coff.COFFObject;
import ddl.coff.COFFWrite;
import ddl.coff.COFFLibrary;
import ddl.coff.COFFImage;
import ddl.coff.cursor;

import ddl.coff.cv4;
import ddl.Utils;
//import ddl.coff.CodeView;
//import ddl.coff.DebugSymbol;

private import std.string;
private import std.stdio;
private import std.stream;
private import std.date;
private import std.conv;
private import std.c.time;

<<<<<<< .mine
private import tango.io.model.IBuffer;
private import tango.io.model.IConduit;

=======
private import mango.io.model.IBuffer;
private import mango.io.model.IConduit;

>>>>>>> .r278
// coff binary type
enum COFF_TYPE : byte
{
	UNKNOWN	= 0x00,
	OBJ		= 0x01,	// obj object file
	LIB		= 0x02,	// lib object file
	OBJECT	= 0x03,	// object type mask
	DLL		= 0x04,	// dll image file
	EXE		= 0x08,	// exe image file
	IMAGE	= 0x0c	// image type mask
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// PE COFF binary file - base class 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class COFFBinary
{
public:
// state
// 	debug (DDL) static bit verbose = true;	// verbose output
// 	else  static bit verbose = false;	// silent
    static bit verbose = false;

	COFF_TYPE coffType 	= COFF_TYPE.UNKNOWN;

<<<<<<< .mine
	bool image 		= false;			// image file or object file
	bool resolved	= false;			// resolved fixups
	char[] filename;					// file name
	char[] name;						// object name
=======
	bit image 		= false;			// image file or object file
	bit resolved	= false;			// resolved fixups
	char[] filename;					// file name
	char[] name;						// object name
>>>>>>> .r278

    // final data
	PublicSymbol[char[]] 	publics;	// public symbols
	ExternalSymbol[] 		externs;	// external symbols
	Fixup[] 				fixups;		// internal fixups
	COFFSection[] 			sections;	// COFF sections

//		FixupThread[4] 		frameThreads;
//		FixupThread[4] 		targetThreads;
	EnumData 			enumData; 		// most recent enum data record
	uint[char[]] 		dependencies; 	// extern index dependencies
	Group[char[]] 		groups;			// section groups

// COFF binary data
	COFFHeader*			coff;			// COFF header
	COFFSymbolRecord[]	symbolTable;	// COFF symbol table
	char[] 				stringTable;	// COFF string table

	COFFSymbol[uint] 	symbols;		// symbols
	Fixup[] 			unresolvedFixups;

// properties

    public char[] getName() { return name; }

	COFF_TYPE type() 					{ return coffType;		    }
	COFF_TYPE type(COFF_TYPE t)		 	{ return coffType = t;	    }

	ExternalSymbol[] getExterns()		{ return externs; 		    }
	PublicSymbol[char[]] getPublics()	{ return publics; 		    }
	Fixup[] getFixups()					{ return fixups; 		    }

    int getSectionCount()			    { return sections.length;   }
	COFFSection[] getSections()			{ return sections; 		    }
	COFFSection getSection(int i)	
    { 
        if( i >= sections.length )
            throw new Exception( "COFFBinary.getSection: invalid section number " ); //~ .toString(i) );
        return sections[i];
    }

<<<<<<< .mine
	bool isImage() 			{ return (coffType & COFF_TYPE.IMAGE) != 0;		}
	bool isObject() 			{ return (coffType & COFF_TYPE.OBJECT) != 0;	}
	bool isObj() 			{ return (coffType & COFF_TYPE.OBJ) != 0;		}
	bool isLib() 			{ return (coffType & COFF_TYPE.LIB) != 0;		}
	bool isDLL() 			{ return (coffType & COFF_TYPE.DLL) != 0;		}
	bool isExe() 			{ return (coffType & COFF_TYPE.EXE) != 0;		}
	
	char[] toString()
	{
		return format( "{0} ({1:8X})", name, filename );
	}
=======
	bit isImage() 			{ return (coffType & COFF_TYPE.IMAGE) != 0;		}
	bit isObject() 			{ return (coffType & COFF_TYPE.OBJECT) != 0;	}
	bit isObj() 			{ return (coffType & COFF_TYPE.OBJ) != 0;		}
	bit isLib() 			{ return (coffType & COFF_TYPE.LIB) != 0;		}
	bit isDLL() 			{ return (coffType & COFF_TYPE.DLL) != 0;		}
	bit isExe() 			{ return (coffType & COFF_TYPE.EXE) != 0;		}
	
	char[] toString()
	{
		return format( "{0} ({1:8X})", name, filename );
	}
>>>>>>> .r278

// lookup string table
	char[] findString( int nOffset )
	{
		// verify state
	 	assert( stringTable.length );
		assert( nOffset >= 4 );
		assert( nOffset < stringTable.length );
		if( nOffset >= stringTable.length )
			return null;

		// copy name
		return std.string.toString( cast(char*) stringTable.ptr + nOffset ).dup;
	}

// utils

	void writeSections()
	{
		// write out each section
		writefln( "\n\tCOFF SECTIONS: ", sections.length );
		if( verbose ) foreach( int nIndex, COFFSection it; sections )
		{
			writeCOFF( it );
		}
	}

	// fixups
	public void fixDependency(char[] name,void* address)
	{
		assert(name in this.dependencies);

		ExternalSymbol* ext = &this.externs[this.dependencies[name]];

		ext.name 		= name;
		ext.address 	= address;
	}

	protected void resolveInternals()
	{	
		// create addresses for all of the public symbols		
		foreach(inout PublicSymbol pub; this.publics)
		{
			debug (DDL) debugLog("resolve: %s segindex: %d offset: %d\n",pub.name,pub.segmentIndex,pub.offset);
			if(pub.segmentIndex == 0)
			{
				pub.address = cast(void*)pub.offset; //HACK: treat as absolute address
				debug (DDL) debugLog("fixed: %s == 0\n",pub.name);
			}
			else
			{
				//TODO: refactor using .getData(uint ofs) to provide a point for group-based addressing
//!!!				pub.address = this.segments[pub.segmentIndex].getData(this.segments,pub.offset);
				//pub.address = &this.segments[pub.segmentIndex].data[pub.offset];
			}
		}

		// go through all the external records, and resolve them to PublicSymbols and Dependencies
		for(uint extIdx=1; extIdx<this.externs.length; extIdx++)
		{
			ExternalSymbol* ext = &(this.externs[extIdx]);
			
		//	if(ext.isResolved) continue; // skip any externals that are already resolved	
			
			if(!ext.isResolved)
			{
				if(ext.name in this.publics)
				{
					PublicSymbol* pub = &(this.publics[ext.name]);
				//	ext.segmentIndex = pub.segmentIndex;
				//	ext.offset = pub.offset;
					ext.address = pub.address;
//!					ext.isResolved = true;
					
					debug (DDL) debugLog("extern %s found as public %0.8X",ext.name,pub.address);
				}
				else
				{
					this.dependencies[ext.name] = extIdx;
				}
			}
		}
	}	
    
    // parse a coff header
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COFF section
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct Group
{
	char[] 			name;
	COFFSection[] 	sections;
}

class COFFSection
{
	COFFSectionHeader header;			// COFF section header
	COFF_TYPE type = COFF_TYPE.UNKNOWN;	// section type - image or object

	uint 	index;						// section number
	uint 	byteAlignment;				// section data alignment
	char[]	name;						// section name
	uint 	nameIndex;
	char[]	group;						// section group name
	uint 	nextInGroup;
	char[]	description;				// section description
	ubyte[]	data;						// section data
    
	COFFRelocationRecord[] 	relocs;		// relocations
	COFFLineRecord[] 		lines;		// line numbers
    
    /*
        properties
    */

    uint getIndex() { return index; }
    char[] getName() { return name; }
    char[] getDescription() { return description; }
    char[] getGroupName() { return group; }
    uint getNextInGroup() { return nextInGroup; }

    // coff section header properties
    uint getFileAddress() { return header.PointerToRawData; }
    uint getFileSize() { return header.SizeOfRawData; }
    uint getAddress() { return header.VirtualAddress; }
    uint getSize() { return header.VirtualSize; }
	uint flags() { return header.Characteristics; }

    /*
        data management
    */

    ubyte[] getData() { return data; }

	void* getDataAt( uint ofs )
	{
		assert( ofs < data.length );
		return &data[ofs];
	}

	// add blocks according to alignment
	void addData(ubyte[] newBlock)
	{
		if(data.length == 0)
		{
			 data = newBlock;
		}
		else
		{
			data.length = data.length + (data.length % byteAlignment);
			data ~= newBlock;
		}
	}

	// getData - allows for grouped segments to represent neighboring places in memory, in order
	void* getDataAt(COFFSection[] allSegments,uint offset)
	{
		if(offset >= data.length)
		{
//			if(nextInGroup == 0)
			{
				throw new Exception("cannot get offset " ~ std.string.toString(offset) ~" in this segment");
			}
//			return allSegments[nextInGroup].getData(allSegments,offset - data.length);
		}
		return &data[offset];
	}

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbols
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// coff symbol
struct COFFSymbol
{
	public:
		char[] 	name;
		uint 	index;
		short 	sectionNumber;
		uint 	offset;
		uint 	value;
		void* 	address;

		int 	type;
		byte 	storageClass;
		byte 	numberOfAuxSymbols;

		// runtime data
		COFFSymbolRecord[] 	auxSymbols;

		// properties
		bool isResolved() 	{ return address != null; }
		bool isFunction() 	{ return type == COFF_SYM_DTYPE_FUNCTION;				}	//	Microsoft tools set this field to 0x20 (function) or 0x0 (not a function)
//		bool isExternal() 	{ return storageClass == IMAGE_SYM_CLASS_WEAK_EXTERNAL;	}
		bool isExternal() 	{ return storageClass == COFF_SYM_CLASS_EXTERNAL;	}
		bool isStatic() 		{ return storageClass == COFF_SYM_CLASS_STATIC;		}
		bool isFile() 		{ return storageClass == COFF_SYM_CLASS_FILE;		}

		char[] toString()
		{
			char[] txt = format( "%s (%d) @ %d:0x%04x - ", name, index, sectionNumber, offset );
			switch( storageClass )
			{
				case COFF_SYM_CLASS_EXTERNAL:	txt ~= "External"; 		break;	// The Value field indicates the size if the section number is COFF_SYM_UNDEFINED (0). If the section number is not 0, then the Value field specifies the offset within the section.
				case COFF_SYM_CLASS_STATIC:		txt ~= "Static";		break;	// The Value field specifies the offset of the symbol within the section. If the Value is 0, then the symbol represents a section name.
				case COFF_SYM_CLASS_FUNCTION:	txt ~= "Function";		break;	// Used by Microsoft tools for symbol records that define the extent of a function: begin function (named .bf), end function (.ef), and lines in function (.lf). For .lf records, Value gives the number of source lines in the function. For .ef records, Value gives the size of function code.
				case COFF_SYM_CLASS_FILE:		txt ~= "Source file"; 	break; 	// Used by Microsoft tools, as well as traditional COFF format, for the source-file symbol record. The symbol is followed by auxiliary records that name the file.
				default:						txt ~= format( "storage: %d", storageClass ); 	break;
			}
			return txt;
		}
//			case COFF_SYM_CLASS_EXTERNAL:			writefln("External" ); 		break;	// The Value field indicates the size if the section number is COFF_SYM_UNDEFINED (0). If the section number is not 0, then the Value field specifies the offset within the section.
//			case COFF_SYM_CLASS_STATIC:				writefln("Static" );		break;	// The Value field specifies the offset of the symbol within the section. If the Value is 0, then the symbol represents a section name.
//			case COFF_SYM_CLASS_FUNCTION:			writefln("Function");		break;	// Used by Microsoft tools for symbol records that define the extent of a function: begin function (named .bf), end function (.ef), and lines in function (.lf). For .lf records, Value gives the number of source lines in the function. For .ef records, Value gives the size of function code.
//			case COFF_SYM_CLASS_FILE:				writefln("Source file"); 	break; 	// Used by Microsoft tools, as well as traditional COFF format, for the source-file symbol record. The symbol is followed by auxiliary records that name the file.

}


// COFF export item
struct COFFExport
{
	uint	Address;
	ushort	Ordinal;
	char[]	Name;
	bool		Forwarded;
	char[]	ForwardName;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// COFF symbols
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// COFF public symbol
struct PublicSymbol
{
	char[] 	name;
	uint 	section;
	uint 	offset;
	void* 	address;
    uint    segmentIndex;

	bool isResolved() 	{ return address != null; }
}

// COFF external symbol
struct ExternalSymbol
{
	// symbol data
	char[] 	name;
	uint 	section;
	uint 	offset;
	void* 	address;

	// extern data
	uint 	tagIndex;
	uint 	style;
	
	// properties
	bool isResolved() 	{ return address != null; }

	char[] toString()
	{
		char[] txt = format( "%s @ %d:0x%04x (0x%08x)", name, section, offset, address );
		return txt;
	}
}

// enum symbol
struct EnumData
{
	uint 	section;
	uint 	offset;
}

struct COFFFixupThread
{
	uint method;
	ushort index;
}

// linker fixup data
struct Fixup
{
	bool isSegmentRelative; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
	bool isExternStyleFixup; // true if this uses an external index as a target, false if it is a segment index
	uint destSectionIndex;
	uint destOffset;
	uint targetIndex; 		// external reference index
}

enum
{
	COFF_SYMBOL_FUNCTION_BEGIN,
	COFF_SYMBOL_FUNCTION_END,
	COFF_SYMBOL_FUNCTION_LINES,
}


// load a coff binary file
COFFBinary loadCOFFFile( char[] filename, bool verbose = false )
{
	char[] ext = filename[$-4..$];
	
	if( ext == ".obj" )
	{
		// load object format
		COFFObject obj = new COFFObject;
		obj.verbose = verbose;
//!		obj.loadFromFile( filename );
		return obj;
	}
	else if( ext == ".exe" || ext == ".dll" )
	{	
		// load module format
		COFFImage mod = new COFFImage;
		mod.verbose = verbose;
//!		mod.loadFromFile( filename );
		return mod;
	}
	return null;
}


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// coff parsing helpers
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

COFFHeader* parseCOFFHeader( File file )
{
	COFFHeader* coff = new COFFHeader;
	if( file.readBlock( coff, COFFHeader.sizeof ) != COFFHeader.sizeof )
	{
		delete coff;
		writefln( "PE module failed to read coff header");
		return null;
	}

	// check machine code
//	if( coff.machine != 0x14C )
//		writefln( "warning: file is not for IA32 Platform!\n" );

	return coff;
}

