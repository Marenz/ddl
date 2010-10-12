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
module ddl.coff.DebugSymbol;

private import ddl.coff.cv4;
private import ddl.coff.CodeView;

private import std.c.windows.windows;

private import std.string;
private import std.stdio;
private import std.conv;
private import std.path;


/////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbol data
/////////////////////////////////////////////////////////////////////////////////////////////////////////

// symbol type
enum DEBUGSYMBOL : uint
{
	NONE		= 0,
	FUNCTION,
	ENDARGS,
	RETURN,
	END,
	BLOCK,
	WITH,
	DATA,
	STACKDATA,
	PUBLIC,
	UDT,
}

// symbol header
class Symbol
{
//	SymbolManager	mgr;
	DEBUGSYMBOL		type;			// symbol type
	uint			address;		// runtime address
	char[]			name;			// name
	char[]			mangled;		// mangled name
	ushort			section;		// image section name
	uint			offset;			// section offset
	uint			size;			// symbol size

	// properties
	uint			addressEnd() 	{ return address + size;	}	// ending runtime address address

	// descriptive string
	char[] toString()
	{
		switch( type )
		{
			case DEBUGSYMBOL.FUNCTION:
				return format( "%s %s%s", functionType, functionName, functionParams );
			case DEBUGSYMBOL.UDT:
				return format( "typedef 0x%04x %s", UDT, name );
			case DEBUGSYMBOL.ENDARGS:
				return "end arguments";
			case DEBUGSYMBOL.PUBLIC:
				return format( "%s %s", CVTypeToString(codeviewType), name );
			case DEBUGSYMBOL.DATA:
				return format( "%s %s", CVTypeToString(codeviewType), name );
			case DEBUGSYMBOL.STACKDATA:
				return format( "%s %s [bp%d]", CVTypeToString(codeviewType), name, stackOffset );
			case DEBUGSYMBOL.RETURN:
				return "return";
			case DEBUGSYMBOL.END:
				return "end";
			case DEBUGSYMBOL.BLOCK:
				return "block";
			case DEBUGSYMBOL.WITH:
				return "with";
			default:
				return format( "%s - unknown type: %d", name, cast(int)type );
		}
		return null;
	}

	// for scoped
	Symbol[]		symbols;

	bool isScope()
	{
		return (type == DEBUGSYMBOL.FUNCTION) || (type == DEBUGSYMBOL.BLOCK) || (type == DEBUGSYMBOL.WITH);
	}
	bool isData()
	{
		return type == DEBUGSYMBOL.DATA;
	}

	bool isStackData()
	{
		return type == DEBUGSYMBOL.STACKDATA;
	}

	// type specific data
	union
	{
		// function
		struct
		{
			char[]		functionName;
			char[]		functionType;
			char[]		functionParams;
			Symbol		functionReturn;
			Symbol		functionEndArgs;
		}

		// data
		struct
		{
			DATATYPE 	dataType;
			ushort		codeviewType;
			int			stackOffset;	// for stack data
		}

		// function return
		struct
		{
			bit			returnPushVargsRight;	// push var args right to left
			bit			returnStackCleanup;		// returnee stack cleanup if true
			ubyte		returnStyle;			// RETURNSTYLE
			ubyte[]		returnRegisters;		// return registers if style is register
		}

		// block
		struct
		{
			uint		blockParent;
			uint		blockEnd;
			uint		blockLength;
		}

		// user defined type
		struct
		{
			ushort		UDT;
		}
	}

}

enum RETURNSTYLE
{
	VOID,
	REGISTER,
	CALLERALLOCATED,
	CALLERALLOCATEDFAR,
	RETURNEEALLOCATED,
	RETURNEEALLOCATEDFAR,
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbol module
/////////////////////////////////////////////////////////////////////////////////////////////////////////

enum MACHINE
{
	UNKNOWN,
	I8080,
	I8086,
	I80286,
	I80386,
	I80486,
	PENTIUM,
}

enum LANGUAGE
{
	UNKNOWN,
	D,
	C,
	CPP,
}

// coff or omf section (or segment) information 
struct BinarySectionInfo
{

	ushort	index;
	uint	offset;
	uint	size;
}

// module containing symbol information
class SymbolModule
{
	public:
	// module attributes
		char[]		name;			// module name
		char[]		sourceFile;		// source code filename
		char[]		compilerVer;	// compiler version string
		int			codeSection;	// PE-COFF module section index
		MACHINE		machine;		// machine code is compiled for
		LANGUAGE	language;		// language code was written in

		uint		codeAddress;	// runtime code address for images (DLL, EXE)

//		bit			hasPCode;		// pcode is available
//		int			floatPrecision;
//		int			floatPackage;
//		int			ambientData;
//		int			ambientCode;

		Symbol[]	moduleScope;			// module scope symbols

	// line <-> address mappings
		uint[uint]	lineMap;		// line[address]
		uint[uint]	addrMap;		// address[line]
		uint[]		lineList;		// sorted lines
		uint[]		addrList;		// sorted addresses

	// data limits
		uint[]		begin;
		uint[]		end;

		uint[]		beginOffset;
		uint[]		endOffset;

	// properties
		ushort		overlay;
		ushort		library;

	// codeview segment info
		BinarySectionInfo[]		sectionInfos;
//		CVSegInfo[]	segInfo;

	// symbols list
		Symbol[]	symbols;
		int			firstSymbol;

		this()
		{
		}

		// find the scope this offset is in
		Symbol findScope( uint offset )
		{
			foreach( Symbol sym; moduleScope )
			{
				if( sym.isScope && (offset >= sym.offset) && (offset <= (sym.offset+sym.size)) )
				{
					return sym;
				}
			}
		}

		// check if address is in module
		bool isInAddress( uint addr )
		{
			return isInAddress( codeSection, addr - codeAddress );
		}

		bool isInAddress( ushort sect, uint offset )
		{
			if( codeSection != sect )
				return false;

			assert( begin.length == end.length );
			for( uint i = 0; i < begin.length; i++ )
			{
//				msgBox( format( "check %x : [%x - %x]\n", addr, begin[i], end[i] ) );
				if( ( offset >= begin[i] ) && ( offset <= end[i] ) )
				{
					return true;
				}
			}
			return false;
		}

		// convert a line to an address
		uint address(uint line)
		{
			// go through sorted line list
			foreach( uint i, uint l; lineList )
			{
				uint a = addrList[i];
				//msgBox( format( "addr from line %d - check %d) line: %d - 0x%08x or 0x%08x", line, i, l, a, addrMap[l] ) );
				if( l >= line )
				{
					//msgBox( format( "found line %d = 0x%08x", l, addrMap[l] ) );
//					msgBox( format("address( %d ) = %d 0x%08x",line,l,addrMap[l]) );
					return addrMap[l];
				}
			}


			return 0;
		}

		// convert an address into closest line
		uint lineFromAddress( uint addr )
		{
//			msgBox( format( "line from addr %x", addr ) );
			assert( addrList.length == lineList.length );

			// not found if no lines
			if(( lineList.length == 0 ) || ( addrList.length != lineList.length ))
				return 0;

//			char[] txt = format( "check 0x%x\n", addr );

			// go through sorted address list
//			for( uint i = 0; i < addrList.length; i++ )
//			{
//				uint a = addrList[i];
//			}

			// check each address
			foreach( uint i, uint a; addrList )
			{
				uint line = lineList[i];
//				msgBox( format( "line from addr 0x%08x - addr %d: 0x%08x - %d", addr, i, a, line ) );
//				txt ~= format( "line %d : 0x%08x\n", l, a );
				if( a == addr )
				{
					//msgBox( format( "found exact %d", lineList[i] ) );
					return lineList[i];
				}
				else if( a > addr )
				{
					// if before first line use first line
					if( i == 0 )
					{
						//msgBox( format( "found first %d", lineList[0] ) );
						return lineList[0];
					}
					// otherwise return previous line
					//msgBox( format( "found prev %d", lineList[i-1] ) );
					return lineList[i-1];

//					msgBox( format("line( 0x%08x ) = %d 0x%08x", addr, lineMap[a], a ) );
//					txt ~= format( "found %d\n", l );
//					return lineMap[a];
				}
			}

			// ran past addresses - return last line
			return lineList[$-1];
		}

		// return next available line
		uint findNextLine( uint line )
		{

			foreach( uint l; lineList )
			{
				if( l >= line )
					return l;
			}

			return 0;
		}


        char[] findFunctionName( uint addr )
		{
            return null;
		}

		// refresh lists & maps
		void refresh()
		{
			// build a sorted line list
			lineList = lineMap.values.dup;
			lineList.sort;

			// build a sorted address list
			addrList = addrMap.values.dup;
			addrList.sort;
		}
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// debug (DDL) symbol management
/////////////////////////////////////////////////////////////////////////////////////////////////////////

// source file location
struct SourceLocation
{
    char[]	file;
    uint 	line;
    ulong 	offset;

	// static initializer
  	static SourceLocation opCall(char[] file, int line)
  	{
    	SourceLocation loc;
    	loc.file = file;
    	loc.line = line;
    	return loc;
  	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////
// type definition base class
////////////////////////////////////////////////////////////////////////////////////////////////////////

class SymbolTypeDefinition
{
	char[]	name;			// name
	char[]	text;			// descriptive text string
	ushort	index;			// type index
	uint	size;			// sizeof

}


////////////////////////////////////////////////////////////////////////////////////////////////////////
// class/struct typedef
////////////////////////////////////////////////////////////////////////////////////////////////////////

enum SYMBOL_ACCESS
{
	None,
	Public,
	Protected,
	Private,
}

// class/struct field base class
class SymbolClassField
{
	public:
		char[]			name;
		SYMBOL_ACCESS	access;
		bool 			isStatic;
		bool 			isVirtual;
		bool 			isFriend;
		char[]			text;


}


// class method function
class SymbolClassMethod : SymbolClassField
{
	public:
		ushort	returnType;
		uint[]	argumentList;
	
		uint	virtualOffset;
		ushort	thisIndex;
		uint	thisAdjust;

		ushort	classType;
	//	ubyte	calling;
}

// class member data
class SymbolClassMember : SymbolClassField
{
	ushort	type;
	uint	offset;
}

// class/struct def
class SymbolClassDef : SymbolTypeDefinition
{
	public:
		bool isClass;			// is a class def
		bool isPacked;			// structure is packed
		bool isForwardRef;		// is only a forward reference
		bool hasCtor;			// has a constructor
		bool hasOverloadedOps;	// has overloaded operators
		bool hasOpAssign;		// has an assignment operator
		bool hasOpCast;			// has a cast operator
		bool isNested;			// nested structure
		bool hasNested;			// contains nested structures
		bool isScoped;			// is scoped

		SymbolClassField[]	fields;			// field list
		SymbolClassMethod[]	methods;		// method functions
		SymbolClassMember[]	members;		// member data
		SymbolClassDef[]	derivationList;	// list of classedefs that directly derive from this classdef

	// base class
		SymbolClassDef	baseClass;		// base class definition
		ushort			baseType;		// base class type index
		ushort			baseAttrib;		// base class flags
		uint			baseOffset;		// base class offset
}


// enum symbol
struct SymbolEnum
{
	char[]	name;
	uint	value;
	ushort	attribute;
}

// enum definition
class SymbolEnumDef : SymbolTypeDefinition
{
	ushort			type;
	ushort			flags;
	SymbolEnum[]	values;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbol data structures
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
// data symbol
struct SymbolData
{
	Symbol		symbol;
	DATATYPE 	type;
	ushort		codeviewType;

	char[] name() 		{ return symbol.name;		}
	char[] mangled() 	{ return symbol.mangled;	}
	uint address() 		{ return symbol.address;	}
	uint size() 		{ return symbol.size;		}

	static SymbolData opCall( in char[] _name, in DATATYPE _type, in uint _segment, in uint _offset )
	{
		SymbolData sym;
		sym.symbol 			= Symbol( _name, DEBUGSYMBOL.DATA, 0, 0 );
		sym.symbol.section 	= _segment;
		sym.symbol.offset 	= _offset;
		sym.type 			= _type;
		return sym;
	}
}
*/

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// function symbol
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
struct SymbolFunction
{
	char[]		mangled;
	char[]		name;
	ushort		section;
	uint		offset;
	uint		address;
	uint		size;

	char[]		functionName;
	char[]		functionType;
	char[]		functionParams;

	uint		addressEnd() 	{ return address + size;	}

//	CVSymProcStart procStart;	// temp. for now

	static SymbolFunction opCall( in char[] _name, in uint _address, in uint _size )
	{
		SymbolFunction sym;
//		sym.symbol 		= Symbol( _name, DEBUGSYMBOL.FUNCTION, _address, _size );
		sym.name 		= _name;
		sym.address 	= _address;
		sym.size 		= _size;
		return sym;
	}

}
*/

// data type
enum DATATYPE : uint
{
	Unknown		= 0,

	// integers
	Int8,
	Int16,
	Int32,
	Int64,
	UInt8,
	UInt16,
	UInt32,
	UInt64,

	// integer pointers
	Int8Ptr,
	Int16Ptr,
	Int32Ptr,
	Int64Ptr,
	UInt8Ptr,
	UInt16Ptr,
	UInt32Ptr,
	UInt64Ptr,

	// reals
	Float,
	Double,

	// real pointers
	FloatPtr,
	DoublePtr,

	// flags
	SIZEMASK		= 0x000f,
	size8			= 0x0001,
	size16			= 0x0002,
	size32			= 0x0003,
	size64			= 0x0004,

	TYPEMASK		= 0x00f0,
	Signed			= 0x0010,
	Unsigned		= 0x0020,
	Boolean			= 0x0030,
	Real			= 0x0040,
	Complex			= 0x0050,

	MODEMASK		= 0x0f00,
	NearPointer		= 0x0100,
	FarPointer		= 0x0200,
	HugePointer		= 0x0300,

	NonPrimitive	= 0x1000,

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// conversion utils
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

char[] dataTypeToString( DATATYPE type )
{
	// custom types
	if( type >= 0x1000 )
		return format("Custom: 0x%04x",cast(uint)type);

	// primitives
	switch( type )
	{
	// 32-bool real
		case DATATYPE.Float:		return "float";
		case DATATYPE.FloatPtr:		return "float*";

	// 8-bool integer
		case DATATYPE.Int8:			return "char";
		case DATATYPE.UInt8:		return "ubyte";
		case DATATYPE.Int8Ptr:		return "char*";
		case DATATYPE.UInt8Ptr:		return "ubyte*";

	// 16-bool integer
		case DATATYPE.Int16:		return "short";
		case DATATYPE.UInt16:		return "ushort";
		case DATATYPE.Int16Ptr:		return "short*";
		case DATATYPE.UInt16Ptr:	return "ushort*";

	// 32-bool integer
		case DATATYPE.Int32:		return "int";
		case DATATYPE.UInt32:		return "uint";
		case DATATYPE.Int32Ptr:		return "int*";
		case DATATYPE.UInt32Ptr:	return "uint*";

	// 64-bool integer
		case DATATYPE.Int64:		return "long";
		case DATATYPE.UInt64:		return "ulong";
		case DATATYPE.Int64Ptr:		return "long*";
		case DATATYPE.UInt64Ptr:	return "ulong*";

	// unhandled type
		default:
			break;
	}

	return format( "Unknown: 0x%04x", cast(uint)type);
}


uint dataTypeSize( DATATYPE type )
{
	// custom types
	if( type >= 0x1000 )
		return 0;

	// primitives
	switch( type )
	{
	// 32-bool real
		case DATATYPE.Float:		return float.sizeof;
		case DATATYPE.FloatPtr:		return (float*).sizeof;

	// 8-bool integer
		case DATATYPE.Int8:			return char.sizeof;
		case DATATYPE.UInt8:		return ubyte.sizeof;
		case DATATYPE.Int8Ptr:		return (char*).sizeof;
		case DATATYPE.UInt8Ptr:		return (ubyte*).sizeof;

	// 16-bool integer
		case DATATYPE.Int16:		return short.sizeof;
		case DATATYPE.UInt16:		return ushort.sizeof;
		case DATATYPE.Int16Ptr:		return (short*).sizeof;
		case DATATYPE.UInt16Ptr:	return (ushort*).sizeof;

	// 32-bool integer
		case DATATYPE.Int32:		return int.sizeof;
		case DATATYPE.UInt32:		return uint.sizeof;
		case DATATYPE.Int32Ptr:		return (int*).sizeof;
		case DATATYPE.UInt32Ptr:	return (uint*).sizeof;

	// 64-bool integer
		case DATATYPE.Int64:		return long.sizeof;
		case DATATYPE.UInt64:		return ulong.sizeof;
		case DATATYPE.Int64Ptr:		return (long*).sizeof;
		case DATATYPE.UInt64Ptr:	return (ulong*).sizeof;

	// unhandled type
		default:					return 0;
	}
	return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbols manager
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
class SymbolManager
{
	public:
		CodeViewData					codeView;

		SymbolTypeDefinition[]			typeDefs;
		SymbolTypeDefinition[ushort]	typeIndexMap;
		SymbolClassDef[]				classDefs;
		SymbolEnumDef[]					enumDefs;
		SymbolModule[]					modules;
		
		uint							codeOffset;
		ushort							codeSection;

	// create from codeview data
		bool parse( CodeViewData cv )
		{
			codeView = cv;

			// parse codeview data
			return parseCodeViewSymbols( this, codeView );
		}

	// source line management
		bool GetLineFromAddr( uint address, out uint line, out char[] file )
		{
			return false;
		}

		SourceLocation* findLocation( uint address )
		{
			return null;
		}

		Symbol findFunction( uint address )
		{
			return null;
		}

		Symbol findData( uint address )
		{
			return null;
		}

		// find the module this address is in
		SymbolModule findModule( uint addr )
		{
			foreach( SymbolModule mod; modules )
			{
				// check if address is in module
				if( mod.isInAddress( addr ) )
				{
					return mod;
				}
			}
			return null;
		}
		// find the module this address is in
		SymbolModule findModule( ushort section, uint offset )
		{
			foreach( SymbolModule mod; modules )
			{
				// check if address is in module
				if( mod.isInAddress( section, offset ) )
				{
					return mod;
				}
			}
			return null;
		}

		// find scope
		Symbol findScope( uint address )
		{
			SymbolModule mod = findModule( codeSection, address - codeOffset );

			return mod.findScope( address - codeOffset );
//			return null;
		}
}
*/
