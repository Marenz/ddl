/+
	Copyright (c) 2005, 2006 J Duncan, Eric Anderton
        
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
	CodeView debug (DDL) data parser

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.CodeViewParser;

import ddl.coff.CodeView;
import ddl.coff.COFF;			// coff win32 api defines
import ddl.coff.cv4;			// codeview 4 api
import ddl.coff.COFFImage;		// coff dll/exe image module
import ddl.coff.cursor;			// DataCursor util
import ddl.coff.COFFReader;     // codeview data reader
import ddl.coff.DebugSymbol;	// debug (DDL) symbol management
import ddl.Demangle;			// mangle/demangle identifier names

import std.stdio;
import std.string;
import std.file;
import std.stream;
import std.c.string;
import std.c.windows.windows;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// codeview data parser
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
class CodeViewParser
{
    CodeViewData            data;

	COFFImage				image;
	uint 					imageBase; 			// loaded image base

	File					file;
	uint 					debugOffset;		// file offset of the debug (DDL) data
	bit						verbose;			// verbose output


	SymbolModule[]			modules;			// sstModule list
	SymbolModule[]			sourceModules;		// sstSrcModule -> source module list
	SymbolModule[char[]]	moduleMap;			// sstSrcModule -> map module names to modules
	SymbolModule[char[]]	sourceMap;			// sstSrcModule -> map source files to modules

	char[][] 				libs;				// sstLibraries -> library list

// public symbols list

	Symbol[]	 			functionSymbols;	// sstGlobalSym -> global functions list
	Symbol[]	 			dataSymbols;		// sstGlobalSym -> global functions list

	Symbol[]				symbols;			// symbols list

	Symbol[]				globalSymbols;		// global symbols list
	Symbol[]				globalPublics;		// global publics

	PIMAGE_SECTION_HEADER 	exeSection;		// executable section

	SymbolTypeDef[ushort] 	types;

	// store special subsections sections
	CVSubSection[]			m_pCVAlignSym;

    this( CodeViewData data_ )
    {
        data = data_;
    }


	///////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// main parsing entry
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // parse a PE-COFF image module
	bit parse( COFFImage image_, File file_ )
	{
		CodeViewSignature	sig;
		CodeViewExternal	ext;
		char[]				fname;

		// save pe image, file, and current offset
		image = image_;
		file = file_;
        debugOffset = file.position;
       
        // create the codeview data if it doesnt exist 
        if(data is null)
            data = new CodeViewData();

		// Get the virtual address of executable code section.
		exeSection = image.findSection( WIN32_IMAGE_SCN_MEM_EXECUTE );
		assert( exeSection );
		if( !exeSection )
			writefln( "image has no executable code section" );
        
		// read the codeview signature
		if( file.readBlock( &sig, CodeViewSignature.sizeof ) != CodeViewSignature.sizeof )
		{
			writefln( "failure reading codeview signature");
			return false;
		}
        
		// debug (DDL) print signature
		if( verbose )
		{
			char sigStr[4];
			memcpy( sigStr.ptr, &sig.Signature, 4 );
			writefln( "\t\tCodeView Signature: {0:8X} ({1})", sig.Signature, sigStr );
			writefln( "\t\tFile offset: {0:8X}", sig.Filepos );
		}

		// set file position to subsection directory
		file.position = debugOffset + sig.Filepos;
//			file.position = debugOffset + CodeViewSignature.sizeof + sig.Filepos;

		// check codeview signature
		if( verbose )
			writef( "\t\tCodeView Version: " );

		switch( sig.Signature )
		{
			case CODEVIEW_SIG_NB09:
				// debug (DDL) print version
				if( verbose ) 
					writefln( "4" );

				// parse code view 4 subsection directory
				parseCV4Directory( );
				//readDebug_CodeViewDir( debugOffset + sig.Filepos );
				break;

			case CODEVIEW_SIG_NB10:		// external pdb file
			case CODEVIEW_SIG_NB11:
				//msgBox( "PDB not supported" );
				assert( false );
				if( verbose ) 
					writefln( "Unsupported CodeView Signature: %d", sig.Signature );
				return false;

			default:				
				if( verbose ) 
					writefln( "Unknown CodeView Signature: %d", sig.Signature );
				return false;
		}

		return true;
	}

	// parse codeview 4 subsection directory
	bit parseCV4Directory( )
	{
		CodeViewHeader cvh;
		int sectionNumber;
		while( true )
		{
			sectionNumber++;
			// read codeview header
			if( file.readBlock( &cvh, CodeViewHeader.sizeof ) != CodeViewHeader.sizeof )
			{
				writefln( "Failure reading codeview header\n");
				return false;
			}

			// debug (DDL) print
			if( verbose )
				writefln(
				"\n\t\tCODEVIEW v4 SECTION HEADER #%d\n"
				"\t\t\tSize of Header: %d\n"
				"\t\t\tSize of Entry: %d\n"
				"\t\t\tNumber of Entries: %d\n"
				"\t\t\tOffset of next Directory: %08X\n"
				"\t\t\tFlags: %08X\n",
				sectionNumber,
				cvh.HeaderSize,
				cvh.EntrySize,
				cvh.NumberOfEntries,
				cvh.NextDirectoryOffset,
				cvh.Flags);

			// verify header size
			assert( cvh.HeaderSize == CodeViewHeader.sizeof );
			if( cvh.HeaderSize != CodeViewHeader.sizeof )
			{
				writefln( "Invalid CodeViewHeader size" );
				return false;
			}

//				CVSubSection		entry;	// = new CVSubSection;

			// set file position to next entry
//				file.position = debugOffset + cvh.NextDirectoryOffset;

			// read the section entries
			CVSubSection[]	dir;
			dir.length = cvh.NumberOfEntries;
			if( file.readBlock( dir.ptr, cvh.NumberOfEntries * CVSubSection.sizeof ) != (cvh.NumberOfEntries * CVSubSection.sizeof) )
			{
				writefln("Failure reading CodeView section entries" );
				return false;
			}

			// process the section entries
			for( uint entrycnt=0; entrycnt < cvh.NumberOfEntries; entrycnt++ )
			{
				// grab entry
				CVSubSection entry = dir[entrycnt];
				assert( entry.Size );

//					debug (DDL) writeCV4( entry );

				// read data
				char[] entryData;
				entryData.length = entry.Size;
				uint startPos 	 = entry.FileOffset + debugOffset;
				file.position 	 = startPos;
				if( file.readBlock( entryData.ptr, entryData.length ) != entryData.length )
				{
					writefln("Failure reading CodeView section entry data" );
					return false;
				}
//					int nLastPos = file.position;

				// create data cursor
//                     FileBuffer fileBuf = new FileBuffer(image.moduleFile);
//             		CodeViewReader reader = new CodeViewReader(fileBuf);

				DataCursor cur;
				cur.data = entryData;
				cur.data.length = entryData.length;
				memcpy( cur.data.ptr, entryData.ptr, entryData.length );

				// debug (DDL) print
				if( verbose ) 
					writef( "\t\tSubSection: #%d (size: %d) - type: ", entrycnt + 1, entry.Size );

				switch( entry.SubsectionType )
				{
					// Basic info. about object module
					case sstModule:
						if( verbose ) 
							writefln( " sstModule - module info" );
						parseModuleEntry( cur );
						break;

					// Alignment symbols table - for each module, there's a matching one of these that contains all the symbol information for it.
					case sstAlignSym:   // module symbols
						if( verbose )
							writefln( " sstAlignSym - module symbols" );

						// grab source module
						assert( sourceModules.length >= m_pCVAlignSym.length );
						SymbolModule mod 	= sourceModules[m_pCVAlignSym.length];

						// add to real modules list
						modules 		~= mod;

						// parse module symbols
						parseModuleSymbols( cur, mod );

						// save symbols table for global indexes
						m_pCVAlignSym ~= entry;
						break;

					//	Module source table - there's one of these per module in PE file
					case sstSrcModule:   // source line information
						if( verbose )
							writefln( " sstSrcModule - module source table" );

						// grab last module
						assert( modules.length == m_pCVAlignSym.length );
						SymbolModule mod = modules[$-1];

						// parse source table
						parseSrcModule( cur, mod );

						break;

					//	This is the global symbol lookup table - instead of searching each module for a
					//	proc address, this table contains an address sort list that allows you to look
					//	up the address directly in one of the alignment symbol tables. Note that there's
					//	only one of these per PE file, although there's also a static symbol table and a
					//	public symbol table (eMT_sstStaticSym and eMT_sstPublic) that are supposed to
					//	do the same sort of thing.
					case sstGlobalSym:
						if( verbose ) 
							writefln( " sstGlobalSym" );
						parseGlobalSymbols( cur );
						break;

					case sstGlobalPub:
						if( verbose ) 
							writefln( " sstGlobalPub" );
						parseGlobalPublics( cur );
						break;


					case sstGlobalTypes:	// global types
						if( verbose ) 
							writefln( " sstGlobalTypes" );
						parseGlobalTypes( cur );
						break;

				// misc
					case sstLibraries:  	// Names of all library files used
						if( verbose ) 
							writefln( " library names" );
						parseLibrariesEntry( cur );
						break;

				// object file types
					case sstPublic:		// Publics --cvpack--> sstGlobalPublics
						if( verbose ) 
							writefln( " sstPublic" );
						break;

					case sstPublicSym:	// Public symbols --cvpack--> sstGlobalSymbols
						if( verbose ) 
							writefln( " sstPublicSym" );
						break;

					case sstTypes:   	// Type information --cvpack--> sstGlobalTypes
						if( verbose )
							writefln( " sstTypes" );
						break;

					case sstSymbols:   		// Symbol Data
						if( verbose )
							writefln( " symbols" );
						parseSymbolsTable( cur, symbols );
						break;

					case sstSrcLnSeg:   	// Source line information
						if( verbose )
							writefln( " source lines" );
						break;


					case sstMPC:
						if( verbose )
							writefln( " MPC" );
						break;

					case sstSegMap:
						if( verbose )
							writefln( " sstSegMap" );
						break;

					case sstSegName:
						if( verbose )
							writefln( " sstSegName" );
						break;

					case sstPreComp:
						if( verbose )
							writefln( " sstPreComp" );
						break;

					case sstPreCompMap:
						if( verbose )
							writefln( " sstPreCompMap" );
						break;

					case sstOffsetMap16:
						if( verbose )
							writefln( " sstOffsetMap16" );
						break;

					case sstOffsetMap32:
						if( verbose )
							writefln( " sstOffsetMap32" );
						break;

					case sstFileIndex:
						if( verbose )
							writefln( " sstFileIndex" );
						break;

					case sstStaticSym:
						if( verbose )
							writefln( " sstStaticSym" );
						break;

					default:
						if( verbose )
							writefln( " unknown type: 0x%x", entry.SubsectionType );
						break;
				}

				// restore file position
//					file.position = nLastPos;
			}

			// if last entry then exit
			if( cvh.NextDirectoryOffset == 0 )
				break;
		}

//			return true;

		///////////////////////////////////////////////////////////////////////////////
		// process module symbols
		///////////////////////////////////////////////////////////////////////////////

		Symbol 		curFunction;
		Symbol 		curScope;
		Symbol[] 	scopeStack;

		// loop through modules
		foreach( SymbolModule mod; modules )
		{

			// set current scope
			void setScope( Symbol moduleScope )
			{
				// push current scope
				if( curScope !is null )
					scopeStack ~= curScope;

				// set current scope
				curScope = moduleScope;

				// set current function
				if( curScope.type == DEBUGSYMBOL.FUNCTION )
					curFunction = curScope;
			}

			void addSymbol( Symbol symbol )
			{
				if( curScope !is null )
					curScope.symbols ~= symbol;
				else
					mod.moduleScope ~= symbol;
			}

			// pop last scope
			void popScope( )
			{
				if( scopeStack.length == 0  )
					curScope = null;
				else
				{
					curScope = scopeStack[$-1];
					scopeStack.length = scopeStack.length - 1;
				}
			}

			foreach( Symbol sym; mod.symbols )
			{
				switch( sym.type )
				{
					case DEBUGSYMBOL.PUBLIC:
						mod.moduleScope ~= sym;
						break;

					case DEBUGSYMBOL.BLOCK:
					case DEBUGSYMBOL.WITH:
						setScope( sym );
						break;

					case DEBUGSYMBOL.FUNCTION:
						addSymbol( sym );
						setScope( sym );
						break;

					case DEBUGSYMBOL.ENDARGS:
						// close out function
						assert( curFunction !is null );
						assert( curFunction.type == DEBUGSYMBOL.FUNCTION );
 						curFunction.functionReturn = sym;
						break;

					case DEBUGSYMBOL.RETURN:
						// close out function
						assert( curFunction !is null );
						assert( curFunction.type == DEBUGSYMBOL.FUNCTION );
 						curFunction.functionEndArgs = sym;
						break;

					// end of function, block, thunk, or with
					case DEBUGSYMBOL.END:
						popScope();
						break;

					case DEBUGSYMBOL.DATA:
//							msgBox( "data: " ~ sym.name );
//							break;
						if( curScope !is null )
							curScope.symbols ~= sym;
						else
							mod.moduleScope ~= sym;
						break;

					case DEBUGSYMBOL.STACKDATA:
						if( curScope !is null )
							curScope.symbols ~= sym;
						else
							mod.moduleScope ~= sym;
						break;

					default:
						throw new Exception( format( "unknown DEBUGSYMBOL %d", cast(uint)sym.type ) );
//							msgBoxf( "unknown DEBUGSYMBOL %d", cast(uint)sym.type );
						break;
				}
			}
		}

		// done
		return true;
	}

	// sstAlignSym directory
	bit parseModuleSymbols( inout DataCursor cur, SymbolModule mod=null )
	{
//			SymbolModule	mod
		if( verbose )
			writefln( "parseModuleSymbols( % 2d  bytes )", cur.length );

		// grab module
//			assert( modules.length > moduleIndex );
//			SymbolModule mod = modules[moduleIndex];

		// find S_SSEARCH - first entry
		while( cur.hasMore )
		{
			ushort len	= cur.parseUSHORT();
			ushort typ	= cur.parseUSHORT();
			if( typ == S_SSEARCH )
			{
				// backup and point to symbol
				cur.position -= 4;
				break;
			}
		}

		// parse all symbols
		while( cur.hasMore )
		{
			// parse a symbol
			Symbol sym = parseSymbol( cur, mod );

		}

		return true;
	}

	// sstSymbols directory
	bit parseSymbolsTable( inout DataCursor cur, inout Symbol[] symbolList )
	{
		if( verbose )
			writefln( "parseSymbolsTable( % 2d  bytes )", cur.length );
		uint i;
		while( cur.hasMore )
		{
			if( verbose )
				writefln( "#%  2d ", ++i );

			// parse the symbol
			Symbol sym = parseSymbol( cur );
			if( sym !is null )
				symbolList ~= sym;
		}

		return true;
	}

	// find the module this address is in
	SymbolModule findModule( ushort section, uint offset )
	{
		foreach( SymbolModule mod; sourceMap )
		{
			// check if address is in module
			if( mod.isInAddress( section, offset ) )
			{
				return mod;
			}
		}
		return null;
	}


	// find the module this address is in
	SymbolModule findModule( uint addr )
	{
		foreach( SymbolModule mod; sourceMap )
		{
			// check if address is in module
			if( mod.isInAddress( addr ) )
			{
				return mod;
			}
		}
		return null;
	}



// parse symbols table
	Symbol parseSymbol( inout DataCursor cur, SymbolModule mod = null )
	{
		Symbol sym;

		ushort symbolLength	= cur.parseUSHORT();

//			if( verbose )	writef( "( %   2d  bytes left ) \tlength: %d ", cur.length, symbolLength );

		if( symbolLength < 2 )
		{
			if( verbose )
				writefln( " too short" );
			return sym;
		}

		ushort symbolType	= cur.parseUSHORT();

		if( verbose )
			writef( "type: 0x%04x - ", symbolType );

		symbolLength -= ushort.sizeof;	// length doesnt include type

		// save next index
		int next = cur.position + symbolLength;
//			cur.position = next;
//			return null;

		// parse a symbol
		switch( symbolType )
		{
		// basic symbols

			// first symbol - module header info
			case S_SSEARCH:
				if( verbose )
					writefln( "S_SSEARCH" );
				uint firstSymOffset = cur.parseUINT();		// offset of first real symbol
				ushort codeSection 	= cur.parseUSHORT();	// PE-COFF section number
				if( mod )
				{
					mod.codeSection = codeSection;
					mod.firstSymbol = firstSymOffset;
				}
				break;

			// compiler flags
			case S_COMPILE:
				ubyte mach 		= cur.parseUBYTE();		// machine type
				ubyte lang 		= cur.parseUBYTE();		// language type
				ushort flags 	= cur.parseUSHORT();	// flags
				char[] ver		= _parseString( cur ); 	// language processor version
				if( verbose )
					writefln( "S_COMPILE\tlanguage processor version: %s\t", ver );
				if( mod )
				{
					// set version
					mod.compilerVer = ver;

					// parse machine code
					switch( mach )
					{
						case 0x00:	mod.machine = MACHINE.I8080; 	break;
						case 0x01:	mod.machine = MACHINE.I8086; 	break;
						case 0x02:	mod.machine = MACHINE.I80286; 	break;
						case 0x03:	mod.machine = MACHINE.I80386; 	break;
						case 0x04:	mod.machine = MACHINE.I80486; 	break;
						case 0x05:	mod.machine = MACHINE.PENTIUM; 	break;
						default:	mod.machine = MACHINE.UNKNOWN;	break;
					}

					// parse language type
					switch( lang )
					{
						case 100:	mod.language = LANGUAGE.D;			break;
						case 0:		mod.language = LANGUAGE.C;			break;
						case 1:		mod.language = LANGUAGE.CPP;		break;
						default:	mod.language = LANGUAGE.UNKNOWN;	break;
					}

				}
//			        parseNumericLeaf( cur );
				break;

			case S_REGISTER:	// register var
				if( verbose )
					writefln( "S_REGISTER" );
				break;

			case S_CONSTANT:	// constant
				if( verbose )
					writefln( "S_CONSTANT" );
				break;

			case S_END:			// end block procedure with or thunk
				if( verbose )
					writefln( "S_END" );

				// create symbol data
				sym 				= new Symbol;
				sym.type 			= DEBUGSYMBOL.END;
				sym.name			= "end";
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_SKIP:		// skip - reserve symbol space
				if( verbose )
					writefln( "S_SKIP" );
				break;
			case S_CVRESERVE:	// internal use
				if( verbose )
					writefln( "S_CVRESERVE" );
				break;
			case S_OBJNAME:		// name of object file
				if( verbose )
					writefln( "S_OBJNAME" );
				break;

			case S_ENDARG:		// end of arguments in function
				if( verbose )
					writefln( "S_ENDARG" );
				// create symbol data
				sym 				= new Symbol;
				sym.type 			= DEBUGSYMBOL.ENDARGS;
				sym.name			= "end args";
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_COBOLUDT:	// COBOL udt
				if( verbose )
					writefln( "S_COBOLUDT" );
				break;

			case S_MANYREG:		// many register symbol
				if( verbose )
					writefln( "S_MANYREG" );
				break;

			case S_RETURN:		// function return description
				if( verbose )
					writefln( "S_RETURN" );

				// parse data
				ushort flags 		= cur.parseUSHORT();
				ubyte style 		= cur.parseUBYTE();

				// create symbol data
				sym 				= new Symbol;
				sym.type 			= DEBUGSYMBOL.RETURN;
				sym.name			= "return";

				// setup flags
				sym.returnPushVargsRight = ( flags & 1 ) != 0;
				sym.returnStackCleanup 	 = ( flags & 2 ) != 0;
				sym.returnStyle 		 = style;

				// parse return registers
				if( style == RETURNSTYLE.REGISTER )
				{
					ubyte numRegs = cur.parseUBYTE();
					while( numRegs-- )
						sym.returnRegisters ~= cur.parseUBYTE();
				}

				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;

//					if( verbose ) writefln( "\tstack data: %s %s (bp %+d)", CVTypeToString(sym.codeviewType), sym.name, sym.stackOffset );
				break;

			case S_ENTRYTHIS:	// description of this pointer at entry
				if( verbose )
					writefln( "S_ENTRYTHIS" );
				break;

	// 16:32 symbols

			// base pointer relative stack data
			case S_BPREL32:
				if( verbose )
					writef( "S_BPREL32" );

				sym = new Symbol;

				// parse symbol
				sym.stackOffset		= cur.parseUINT();
				sym.codeviewType  	= cur.parseUSHORT();
				sym.mangled		 	= _parseString( cur );

				// setup symbol data
				sym.type 			= DEBUGSYMBOL.STACKDATA;
				sym.name		 	= sym.mangled;
				sym.dataType 		= convertCVType( sym.codeviewType );
				sym.size 			= dataTypeSize( sym.dataType );

//					DSymbol DSym 		= demangle( sName );
//					sym.symbol.name 	= DSym.name;

				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;

				if( verbose ) 
					writefln( "\tstack data: %s %s (bp %+d) (%s)", CVTypeToString(sym.codeviewType), sym.name, sym.stackOffset, sym.mangled );

				break;

			case S_UDT:			// user data types
				// parse symbol
				sym 				= new Symbol;
				sym.type			= DEBUGSYMBOL.UDT;
				sym.UDT				= cur.parseUSHORT();
				sym.name		 	= _parseString( cur );
				if( verbose )
					writefln( "S_UDT\t- %s - 0x%04x", sym.name, sym.UDT );
//					msgBoxf( "udt: 0x%04x - %s", sym.UDT, sym.name );
				break;

			case S_LDATA32:		// local data
				if( verbose )
					writef( "S_LDATA32 " );
				sym = parse_DATA32( cur );
				if( verbose )
					writefln( sym.name );

				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;

				break;


			case S_GDATA32:		// global data
				if( verbose )
					writefln( "S_GDATA32 " );
				sym = parse_DATA32( cur );
				if( verbose )
					writefln( sym.name );
 			//	msgBox( sym.name );
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;

				break;

			case S_PUB32:		// public symbol
				sym = parse_PUB32( cur );
				if( verbose )
					writefln( "S_PUB32 - %s - %s", sym.name, CVTypeToString( sym.codeviewType ) );
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_LPROC32:		// local procedure
				sym = parse_PROC32( cur );
				if( verbose )
					writefln( "S_LPROC32 %s", sym.name );

				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_GPROC32:		// global procedure
				sym = parse_PROC32( cur );
				if( verbose )
					writefln( "S_GPROC32 - %s", sym.name );
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_PROCREF:
				if( verbose )
					writef( "S_PROCREF - " );
//					sym = parse_PROCREF( cur );

				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			// alignment symbol - padding
			case S_ALIGN:
				cur.position +=	symbolLength;
				break;

			default:
//					cur.position +=	symbolLength;
//					msgBoxf( "unhandled symbol type 0x%x", cast(uint)symbolType );
				if( verbose )
					writefln( "\t\tunhandled symbol type: 0x%04x", symbolType );
				break;

			case S_BLOCK32:		//  block start
				if( verbose ) writefln( "S_BLOCK32" );
				// create symbol data
				sym 				= new Symbol;
				sym.type 			= DEBUGSYMBOL.BLOCK;
				sym.name			= "BLOCK";
				sym.blockParent		= cur.parseUINT();
				sym.blockEnd		= cur.parseUINT();
				sym.blockLength		= cur.parseUINT();
				sym.offset			= cur.parseUINT();
				sym.section			= cur.parseUSHORT();
//					sym.name			= _parseString( cur );
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;

			case S_WITH32:		// with start
				if( verbose ) writefln( "S_WITH32" );
				// create symbol data
				sym 				= new Symbol;
				sym.type 			= DEBUGSYMBOL.WITH;
				sym.name			= "WITH";
				sym.blockParent		= cur.parseUINT();
				sym.blockEnd		= cur.parseUINT();
				sym.blockLength		= cur.parseUINT();
				sym.offset			= cur.parseUINT();
				sym.section			= cur.parseUSHORT();
//					sym.name			= _parseString( cur );
				// add symbol to module
//					if( mod )
//						mod.symbols ~= sym;
				break;


/*

			case S_LABEL32:		//
				writefln( "S_LABEL32" );
				break;
			case S_THUNK32:		// thunk start
				writefln( "S_THUNK32" );
				break;

			case S_CEXMODEL32:	//
				writefln( "S_CEXMODEL32" );
				break;
			case S_VFTTABLE32:	// virtual function table
				writefln( "S_VFTTABLE32" );
				break;
			case S_REGREL32:	// register
				writefln( "S_REGREL32" );
				break;
			case S_LTHREAD32:	// local thread storage data
				writefln( "S_LTHREAD32" );
				break;
			case S_GTHREAD32:	// global thread storage data
				writefln( "S_GTHREAD32" );
				break;


			// public symbol
			//case S_PUB32:
			//	break;

			// global data symbol
//					case S_GDATA32:

//							writefln( "S_GDATA32 symbol: %s type: %d segment: %d offset: 0x0%x", sName, dat.type, dat.segment, dat.offset );

				// grab current memory address
		//		if( curAddress )
		//			sym.symbol.address = curAddress;

				CVSymbolData* dat = cast(CVSymbolData*)pSymData; 	pSymData += CVSymbolData.sizeof;
				// copy name
				char[] sName;
				sName.length = dat.nameLength;
				memcpy( sName.ptr, pSymData, dat.nameLength );
				pSymData += dat.nameLength;
				writefln( "S_GDATA32 symbol: %s type: %d segment: %d offset: 0x0%x", sName, dat.type, dat.segment, dat.offset );
//						break;

			// data reference
		//	case S_DATAREF:
		//		writefln( "S_DATAREF" );
				// data reference
		//		break;
			// procedure reference
//					case S_PROCREF	:
//						cur.data.ptr + cur.position
//						SymbolFunction func = parse_PROCREF(  );

				// grab current memory address
//						if( curAddress )
//							func.address = curAddress;

//							parseSymbol_S_PROCREF( );
//							void parseSymbol_S_PROCREF( )

//							writefln( procData.m_NameLen );
//							writefln( procName );
//							procName.length = pProcData.m_NameLen;
//							_sntprintf(pData->m_Fnc,eMaxFncName,_T("%.*s"),pProcData->m_NameLen,pProcData->m_Name);
				break;
*/
			//	Can also do S_DATAREF for variables (see MSDN documentation and CVSymData for details)
		}

		cur.position = next;

		if( sym !is null )
		{
			if( mod is null )
			{
				// find module
			//	mod = findModule( sym.section, sym.offset );
			}

			if( mod !is null )
			{
//					writefln( "module add: ", sym.name );
				mod.symbols ~= sym;
			}
		}

//			debug (DDL) writefln( "pos = 0x%04x len = %d", next, cur.length );
		return sym;
	}

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	// parse symbols
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// S_PROCREF - procedure reference
	Symbol parse_PROCREF( inout char* data )
	{
		Symbol func;

		assert( m_pCVAlignSym.length );

		// grab procedure reference header
		CVSymProcRef* pProcRef = cast(CVSymProcRef*)data;
		data += CVSymProcRef.sizeof;
		assert( pProcRef.moduleIndex <= m_pCVAlignSym.length );

		if( pProcRef.moduleIndex > m_pCVAlignSym.length )
		{
			writefln( "error - incomplete codeview data - ?" );
			return func;
		}
//	uint	checksum;		// checksum Checksum of the referenced symbol name. The checksum used is the one specified in the header of the sstGlobalSym or sstStaticSym subsections.
//	uint	symOffset;		// offset Offset of the procedure symbol record from the beginning of the $$SYMBOL table for the module.
//	ushort	moduleIndex;	// module Index of the module that contains this procedure record.
		// find address from alignment symbol
		uint modAddr	= debugOffset + m_pCVAlignSym[pProcRef.moduleIndex-1].FileOffset;
		uint dataAddr 	= modAddr + pProcRef.symOffset + 4;

		// parse symbol
		func = parse_PROC32( dataAddr );

		//debug (DDL) writefln( "\t\tprocref - mod: %d offset: %d ", pProcRef.moduleIndex, pProcRef.symOffset );
		return func;
	}

// parse a procedure reference
	Symbol parse_PROCREF( inout DataCursor cur )
	{
		Symbol func;

		assert( m_pCVAlignSym.length );

		// grab procedure reference header
		CVSymProcRef* pProcRef = cast(CVSymProcRef*)cur.ptr;
		cur.position += CVSymProcRef.sizeof;
		assert( pProcRef.moduleIndex <= m_pCVAlignSym.length );

		if( pProcRef.moduleIndex > m_pCVAlignSym.length )
		{
			writefln( "error - invalid codeview data" );
			return func;
		}

		// find address from alignment symbol
		uint modAddr	= debugOffset + m_pCVAlignSym[pProcRef.moduleIndex-1].FileOffset;
		uint dataAddr 	= modAddr + pProcRef.symOffset + 4;

		// parse symbol
		func = parse_PROC32( dataAddr );

		try
		{
			if( verbose )
				writefln( "S_PROC32 -> %s", func.name );
		}
		catch( Object e )
		{
			writefln( e.toString );
		}

		//debug (DDL) writefln( "\t\tprocref - mod: %d offset: %d ", pProcRef.moduleIndex, pProcRef.symOffset );
		return func;
	}

// create a symbol function
	Symbol createFunction( CVSymProcStart* procStart, in char[] procName )
	{
		Symbol func			= new Symbol;
		func.type			= DEBUGSYMBOL.FUNCTION;
		func.mangled		= procName.dup;
		func.section 		= procStart.m_Section;
		func.offset 		= procStart.m_Offset;
		func.size 			= procStart.m_ProcLength;

		// demangle name
		func.name			= demangleSymbol( func.mangled );

		bit splitFunctionDeclaration( in char[] decl, out char[] type, out char[] name, out char[] params )
		{
			int i = find( decl, ' ' );
			if( i == -1 )
				return false;

			type = decl[0..i];
			int j = find( decl[i..$], '(' );
			if( j == -1 )
				return false;

			type = decl[i..j];
			int k = find( decl, ')' );
			if( k == -1 )
				return false;

			type = decl[j..k];
			return true;
		}

		splitFunctionDeclaration( func.name, func.functionType, func.functionName, func.functionParams );

//			func.functionName	= func.name;
//			func.functionType	= func.name;
//			func.functionParams	= func.name;

//			int i = find(

/**

		// demangle name
		try
		{
			DSymbol DSym 		= demangle( func.mangled );
			func.name			= DSym.name.dup;
			func.functionName	= DSym.functionName.dup;
			func.functionType	= DSym.functionType.dup;
			func.functionParams	= DSym.functionParams.dup;
		}
		catch( Object o )
		{
			throw new Exception( format( o.toString, "CodeViewData.createFunction - demangle exception" ) );
		}
*/
		// add function to list
		functionSymbols	~= func;
		symbols 		~= func;
		//debug (DDL) writefln( "\t\tprocref - mod: %d offset: %d ", pProcRef.moduleIndex, pProcRef.symOffset );
		return func;
	}

// S_GPROC32 & S_LPROC32 - global and local procedures
	Symbol parse_PROC32( uint fileOffset )
	{
		// move file position to offset
		file.position = fileOffset;
		// read process reference structure - CVSymProcStart
		CVSymProcStart procStart;
		file.readBlock( &procStart, CVSymProcStart.sizeof );

		ubyte nameLen;
		file.readBlock( &nameLen, ubyte.sizeof );

		// copy name
		char[] procName;
		if( (procName.length = nameLen) != 0 )
			file.readBlock( procName.ptr, nameLen );

		// create function
		return createFunction( &procStart, procName );
	}

	// parse a process from a cursor
	Symbol parse_PUB32( inout DataCursor cur )
	{
		// create function
//			Symbol sym = createFunction( procStart, procName );
		Symbol sym = parse_DATA32( cur );

		sym.type = DEBUGSYMBOL.PUBLIC;

		return sym;
	}

	// parse a process from a cursor
	Symbol parse_PROC32( inout DataCursor cur )
	{
		// read process reference structure - CVSymProcStart
		CVSymProcStart* procStart = cast(CVSymProcStart*)cur.ptr;
		cur.position += CVSymProcStart.sizeof;
		/*
		if( cur.length > 256 )
		{
			int pos = cur.position;

			char c = cur.peek();
			ushort l = cur.parseUSHORT();
			debug (DDL) writefln( "\n! 0x%02x 0x%04x", c, l );

//					if( symbolLength > 300 )
			{
				debug (DDL) writefln( "S_GPROC32! length: %d - 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", cur.length, cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE() );
//						msgBoxf( "%02x %02x %02x %02x", cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE(), cur.parseUBYTE() );
				//cur.parseUBYTE()
//						break;
			}
//				msgBoxf( "%x", cur.peek );

			//cur.parseUBYTE()
			cur.position = pos;
		}

		// parse name
		ubyte strLen = cur.parseUBYTE();
		writef( "string len: %d (0x%x) - ", strLen, strLen );
		char[] procName	= cur.parseString( strLen );
		*/
		char[] procName	= _parseString( cur );

		// create function
		return createFunction( procStart, procName );
	}


	// S_GDATA32 & S_LDATA32 - global and local data symbols
	Symbol parse_DATA32( inout DataCursor cur )
	{
		// get sst data structure & advance position
		CVSymbolData* dat = cast(CVSymbolData*)cur.ptr;
		cur.position += CVSymbolData.sizeof;
//			msgBoxf( "parse_DATA32 size = %d - namelen = ", cur.length, cast(uint) cur.peek() );

		// parse name
		char[] sName		= _parseString( cur );

		Symbol sym 			= new Symbol;
		sym.type			= DEBUGSYMBOL.DATA;
		sym.section 		= dat.segment;
		sym.offset 			= dat.offset;
		sym.codeviewType 	= dat.type;
		sym.mangled 		= sName;
		sym.name 			= sName;

//			msgBox( "created " ~ sName );

		sym.dataType 		= convertCVType( sym.codeviewType );

		// demangle name
//			if( sName[0] == '_' )
//				sName			= sName[1..$];

//!			DSymbol DSym 		= demangle( sName );
//!			sym.name 			= DSym.name;
		sym.name			= demangleSymbol( sName );

//			SymbolType symType	= DSym.type;
//			msgBoxf( "data: %s %d", DSym.name, cast(uint)DSym.type );

//			sym.symbol.name = DSym.name;

//			sym.symbol.address	= 0;
//			sym.symbol.size 	= 0;
		/*
		// demangle name
		try
		{
//				SymbolType symType;
//				DSymbol DSym 		= demangleSymbol( sName, symType );
//				char[] sDemangle 	= demangleSymbol( sName, symType );
			DSymbol DSym 		= demangle( sName );
		}
		catch( Object e )
		{
			msgBox( e.toString, "demangle exception" );
		}
		*/

		symbols ~= sym;
		
		// find module

//			writefln( "S_GDATA32 %s (type: %s section: %d offset: 0x0%x)", sName, CVTypeToString( dat.type ), dat.segment, dat.offset );
		return sym;
	}

// parse global publics
	bit parseGlobalPublics( inout DataCursor cur )
	{
		char* pGlobalSymBase	= cur.data.ptr;
//			char* pDataPtr			= cur.data.ptr;

		// parse symbol table header
		CVSymTableHeader* pSymTableHdr	= cast(CVSymTableHeader*)cur.ptr;
		cur.position += CVSymTableHeader.sizeof;

		uint symTableOffset		= cur.position;
		char* pSymTable			= cur.ptr;

		// verify header
		assert(pSymTableHdr.symHashFnc == 10);
		assert(pSymTableHdr.addrHashFnc == 12);
		if((pSymTableHdr.symHashFnc != 10) || (pSymTableHdr.addrHashFnc != 12))
			return false;

		// create symbol table cursor and parse
		DataCursor symCursor = cur.cursor(pSymTableHdr.numSymBytes);

//			symCursor.data 	= cur.data[ cur.position .. cur.position + pSymTableHdr.numSymBytes ];

		if( !parseSymbolsTable( symCursor, globalPublics ) )
			return false;

		return true;
	}
	
// parse global symbols
	bit parseGlobalSymbols( inout DataCursor cur )
	{
		char* pGlobalSymBase	= cur.data.ptr;
//			char* pDataPtr			= cur.data.ptr;

		// parse symbol table header
		CVSymTableHeader* pSymTableHdr	= cast(CVSymTableHeader*)cur.ptr;
		cur.position += CVSymTableHeader.sizeof;

		uint symTableOffset		= cur.position;
		char* pSymTable			= cur.ptr;

		// verify header
		assert(pSymTableHdr.symHashFnc == 10);
		assert(pSymTableHdr.addrHashFnc == 12);
		if((pSymTableHdr.symHashFnc != 10) || (pSymTableHdr.addrHashFnc != 12))
			return false;

		// create symbol table cursor and parse
		DataCursor symCursor = cur.cursor(pSymTableHdr.numSymBytes);

//			symCursor.data 	= cur.data[ cur.position .. cur.position + pSymTableHdr.numSymBytes ];

		if( !parseSymbolsTable( symCursor, globalSymbols ) )
			return false;

		return true;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////////////
	// codeview types
	/////////////////////////////////////////////////////////////////////////////////////////////

	// parse a Type String - a list of leaf type data

	SymbolTypeDef parseTypeString( inout DataCursor inCur )
	{
		ushort len 	= inCur.parseUSHORT();
		char* str	= inCur.ptr;
		char* ptr 	= inCur.ptr;
		char* end 	= inCur.ptr + len - 1;

		// create data cursor
		DataCursor cur;
		cur.data.length = len;
		memcpy( cur.data.ptr, inCur.ptr, len );

		// create a symbol typedef
		SymbolTypeDef sym;

		// loop through string
//			while( ptr <= end )
//			writefln( "parseTypeString" );
		while( cur.hasMore() )
		{
			char[] leafString;

			// grab leaf
			ushort leaf = cur.parseUSHORT();

//				ushort leaf = *cast(ushort*) ptr;
//				ptr += ushort.sizeof;
			// get type string
			sym.typeString = leafToString( leaf );

			if( verbose )
				writefln( "\tparse leaf: %s (remain %d)", sym.typeString, cur.length );
//				debug (DDL) writefln( "\tparse leaf: %s (remain %d)", sym.typeString, cur.length );

			switch( leaf )
			{
			    case LF_MODIFIER_V1:	// modifier
			    case LF_POINTER_V1:		// pointer
			    case LF_PROCEDURE_V1:	// procedure type
				case LF_ARGLIST_V1:		// argument list
			    case LF_ARRAY_V1:
			    case LF_STRUCTURE_V1:
			    case LF_CLASS_V1:
				case LF_FIELDLIST_V1:
				case LF_ENUM_V1:
			    case LF_MFUNCTION_V1:
				case LF_METHODLIST_V1:
			    case LF_VTSHAPE_V1:
			    case LF_UNION_V1:
				case LF_DERIVED_V1:
			        break;

			    default:
					if( verbose )
						throw new Exception( format( "unhandled leaf type (0x%04x) %s", leaf, sym.typeString ) );
//						int i = 0;
//						char[] str;
//						while( cur.hasMore )
//						{
//							str ~= format( "%d - 0x%04x\n", ++i, cast(int)cur.parseUBYTE() );
//						}
//						msgBox( str );
//						return sym;
					break;
			}

			// parse leaf
			int length;
			switch( leaf )
			{
			// symbol leafs
			    case LF_MODIFIER_V1:	// modifier
			        sym.type 			= typeMODIFIER;
			        sym.modifierType 	= cur.parseUSHORT();
			        sym.modifierAttrib 	= cur.parseUSHORT();
			        leafString = format( "modifier 0x%04x - 0x%x", sym.modifierType, sym.modifierAttrib );
				    break;

			    case LF_POINTER_V1:		// pointer
			        sym.type 			= typePOINTER;
			        sym.pointerType 	= cur.parseUSHORT();
			        sym.pointerAttrib 	= cur.parseUSHORT();
			        ushort attrib 		= sym.pointerAttrib;
			        leafString = format( "pointer 0x%04x - 0x%x", sym.pointerType, sym.pointerAttrib );

			        ushort ptrtype = attrib & 0x1f;
			        ushort ptrmode = (attrib >> 5) & 0x03;

//0 Pointer
//1 Reference
//2 Pointer to data member
//3 Pointer to method
					// parse variant data
					switch( ptrtype )
					{
						case 0:		// Near

							break;

						case 1:		// Far
							break;
						case 2:		// Huge
							break;
						case 3:		// Based on segment
							break;
						case 4:		// Based on value
							break;
						case 5:		// Based on segment
							break;
						case 6:		// Based on address
							break;
						case 7:		// Based on segment
							break;
						case 8:		// Based on type
							break;
						case 9:		// Based on self
							break;
						case 10:	// Near 32-bit pointer
							break;
						case 11:	// Far 32-bit pointer
							break;
						default:
							break;
					}

				// variant data
					if( ptrtype == 3 )
					{
						// based on segment
					}
					if( ptrtype == 8 )
					{
						// based on type
					}
					else if( ptrtype == 9 )
					{
						// based on self
					}

					if( ptrmode == 2 )
					{
						// ptr to data member
						length = 4;
					}
					else if( ptrmode == 3 )
					{
						// ptr to method
						length = 4;
					}

					leafString = format( "ptr - type: 0x%04x %s %d %d", sym.pointerType, CVTypeToString( sym.pointerType ).dup, ptrtype, ptrmode );
				    break;

			    case LF_ARRAY_V1:
			        ushort	arrayType		= cur.parseUSHORT();		// element type
			        ushort	indexType		= cur.parseUSHORT();		// index type
			        uint 	arraySize		= parseNumericLeaf( cur );	// length of array
			        char[] 	name			= _parseString( cur );
//						ubyte	nameSize		= cur.parseUBYTE();	// name length
//						char[] 	name			= cur.parseString( nameSize ).dup;

					// setup symbol
					sym.name		= name;
					sym.type 		= typeARRAY;
					sym.arrayType 	= arrayType;
					sym.arrayIndex 	= indexType;
					sym.arraySize 	= arraySize;

					leafString 		= format( "%s[%s]", CVTypeToString(arrayType), CVTypeToString(indexType) );
				    break;

			    case LF_CLASS_V1:
//			        	msgBox( "class" );

			    case LF_STRUCTURE_V1:
			        //if( leaf == LF_CLASS_V1 )
				    //	msgBoxf( "class %d", cur.length );
			        //else
				    //	msgBoxf( "struct %d", cur.length );
			        sym.structLeafCount			= cur.parseUSHORT();	// member count
			        sym.structFieldList			= cur.parseUSHORT();	// field list index
			        sym.structFlags 			= cur.parseUSHORT();	// property flags
			        sym.structDerivationList	= cur.parseUSHORT();	// derevation list
			        sym.structVShape			= cur.parseUSHORT();	// vshape
			        sym.size					= cast(uint)parseNumericLeaf( cur );
					sym.name					= _parseString( cur );
			        sym.type 					= (( leaf == LF_CLASS_V1 ) ? typeCLASS : typeSTRUCT);

			        leafString = format( "%s %s - fieldlist: 0x%04x", (( leaf == LF_CLASS_V1 )?"class":"struct"), sym.name, sym.structFieldList );
				    break;

			    case LF_UNION_V1:
					sym.type				= typeUNION;
			        sym.unionCount 			= cur.parseUSHORT();
			        sym.unionListIndex 		= cur.parseUSHORT();
			        sym.unionProperties		= cur.parseUSHORT();
			        sym.unionSize			= cast(uint)parseNumericLeaf( cur );
					sym.name				= _parseString( cur );

					if( cur.hasMore )
					{
						int i = 0;
						char[] s2 = format( "union left: %d\n", cur.length );
						while( cur.hasMore )
							s2 ~= format( "%d - 0x%04x\n", ++i, cast(int)cur.parseUBYTE() );
//							msgBox( s2 );
					}
				    break;

			    case LF_ENUM_V1:
					sym.type				= typeENUM;
			        sym.enumCount 			= cur.parseUSHORT();
			        sym.enumType 			= cur.parseUSHORT();
			        sym.enumList 			= cur.parseUSHORT();
			        sym.enumFlags 			= cur.parseUSHORT();
					sym.name				= _parseString( cur );
				    break;

			    case LF_PROCEDURE_V1:	// procedure type

					sym.type 					= typePROCEDURE;
					sym.procedureReturnType 	= cur.parseUSHORT();	// function return val
					sym.procedureCalling 		= cur.parseBYTE();		// calling convention
					cur.parseBYTE();									// reserved
					sym.procedureParams 		= cur.parseUSHORT();	// parameter count
					sym.procedureArglist 		= cur.parseUSHORT();	// arglist type index
			        leafString = format( "proc - retval: %s, calling: %d, params: %d, arglist: 0x%04x", CVTypeToString( sym.procedureReturnType ), sym.procedureCalling, sym.procedureParams, sym.procedureArglist );

					sym.name					= leafString;
				    break;

				// member function
			    case LF_MFUNCTION_V1:
					sym.type 					= typeMEMFUNC;
					sym.memfuncReturnType	 	= cur.parseUSHORT();
					sym.memfuncClassType 		= cur.parseUSHORT();
					sym.memfuncThisIndex 		= cur.parseUSHORT();
					sym.memfuncCalling 			= cur.parseUBYTE();
					cur.parseUBYTE();
					sym.memfuncArgCount 		= cur.parseUSHORT();
					sym.memfuncArgList 			= cur.parseUSHORT();
					sym.memfuncThisAdjust 		= cur.parseUINT();
				    break;

			    case LF_VTSHAPE_V1:

					//! fix
//						ushort count = cur.parseUSHORT();
					ushort count = 1;
//						cur.position += count * 1;
					char[] str2 = format( "vt shape count: %d\n", count );
					int i = 0;
					while( cur.hasMore )
					{
						str2 ~= format( "%d - 0x%04x\n", ++i, cast(int)cur.parseUBYTE() );
					}
//						msgBox( str2 );

				    break;

			    case LF_COBOL0_V1:
			        length = 4;
				    break;
			    case LF_COBOL1_V1:
			        length = 4;
				    break;
			    case LF_BARRAY_V1:
			        length = 4;
				    break;
			    case LF_LABEL_V1:
			        length = 4;
				    break;
			    case LF_NULL_V1:
			        length = 4;
				    break;
			    case LF_NOTTRAN_V1:
			        length = 4;
				    break;
			    case LF_DIMARRAY_V1:
			        length = 4;
				    break;
			    case LF_VFTPATH_V1:
			        length = 4;
				    break;
			    case LF_PRECOMP_V1:
			        length = 4;
				    break;
			    case LF_ENDPRECOMP_V1:
			        length = 4;
				    break;
			    case LF_OEM_V1:
			        length = 4;
				    break;
			    case LF_TYPESERVER_V1:
			        length = 4;
				    break;

			// type-record leafs

				case LF_SKIP_V1:
					break;

				case LF_ARGLIST_V1:		// argument list
					sym.type = typeARGLIST;
//						ushort argCount = *cast(ushort*)ptr; ptr += ushort.sizeof;
					ushort argCount = cur.parseUSHORT();
					char[] argList = "(";
//						msgBoxf( "%d - %d", argCount, cur.length() );
					for( uint a = 0; a < argCount; a++ )
					{
						ushort arg = cur.parseUSHORT();
//							msgBoxf( "0x%04x [%s] - %d", arg, CVTypeToString( sym.pointerType ) , cur.length() );
						argList ~= CVTypeToString( arg );
						if( a != argCount-1 )
							argList ~= ", ";
						sym.arglist ~= arg;
					}
					argList ~= ")";
//						msgBox( argList );
					sym.argString = argList.dup;
					leafString = argList.dup;
//						msgBoxf( "arglist [len=%d] (%s)", argCount, argList );
					break;

				case LF_DEFARG_V1:
					break;
				case LF_LIST_V1:
					break;

				case LF_FIELDLIST_V1:

					// setup type
					sym.type = typeFIELDLIST;

					// parse a list of fields
					while( cur.hasMore() )
					{
						//msgBoxf( "field %d - %s", sym.fieldList.length+1, leafToString(fieldLeaf) );
						// parse class/struct field into member
						CodeViewField field = parseFieldLeaf( cur );

						// add to member list
						sym.fieldList 	~= field;

						// check paddings - The byte at the new address is examined and if it is greater than 0xf0, the low four bits are extracted and added to the address to find the address of the next subfield.
						if( cur.hasMore() )
						{
							ubyte pad = cast(ubyte)cur.peek();
							if( pad > 0xf0 )
							{
								pad &= 0x0f;
								cur.position += pad;
							}
						}
					}

					break;

				case LF_DERIVED_V1:
					sym.type		= typeDERIVED;
			        ushort cnt		= cur.parseUSHORT();
//			        	msgBoxf( "derived ", cnt );
			        while( cnt-- )
				        sym.derivedList ~= cast(ushort)cur.parseUSHORT();
				        //msgBoxf( cast(ushort)cur.parseUSHORT() );

					break;

				case LF_BITFIELD_V1:
					break;

				case LF_METHODLIST_V1:

					sym.type	= typeMETHODLIST;
//						while( cur.hasMore() )
					{
						SymbolMethod meth;
						meth.attributes = cur.parseUSHORT();
						meth.type 		= cur.parseUSHORT();
//							msgBoxf( "%x", meth.type );
//							msgBoxf( "method type: 0x%04x", meth.type );
						//if( fieldAttribIsVirtual( meth.attributes ) )
						//	meth.virtualOffset = cur.parseUSHORT();
						sym.methodList ~= meth;
					}

					// for now only take first - need to decifer virtual flags proper
					//while( cur.hasMore() )
					//	cur.parseBYTE();

					cur.position = cur.data.length;
					break;

				case LF_DIMCONU_V1:
					break;
				case LF_DIMCONLU_V1:
					break;
				case LF_DIMVARU_V1:
					break;
				case LF_DIMVARLU_V1:
					break;
				case LF_REFSYM_V1:
					break;

			// leafs

				default:
				    break;
			}

			// numeric leafs
			switch( leaf )
			{
			    case LF_CHAR:
			        length += 1;
//			            *value = *(const char*)leaf;
		        break;

			    case LF_SHORT:
			        length += 2;
//			            *value = *(const short*)leaf;
			        break;

			    case LF_USHORT:
			        length += 2;
//			            *value = *(const unsigned short*)leaf;
			        break;

			    case LF_LONG:
			        length += 4;
//			            *value = *(const int*)leaf;
			        break;

			    case LF_ULONG:
			        length += 4;
//			            *value = *(const unsigned int*)leaf;
			        break;

			    case LF_QUADWORD:
			    case LF_UQUADWORD:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 8;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_REAL32:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 4;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_REAL48:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 6;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_REAL64:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 8;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_REAL80:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 10;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_REAL128:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 16;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_COMPLEX32:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 4;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_COMPLEX64:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 8;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_COMPLEX80:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 10;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_COMPLEX128:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
			        length += 16;
//			            *value = 0;    /* FIXME */
			        break;

			    case LF_VARSTRING:
				    //FIXME("Unsupported numeric leaf type %04x\n", type);
//			            length += 2 + *leaf;
//			            *value = 0;    /* FIXME */
			        break;

			    default:
			 		//FIXME("Unknown numeric leaf type %04x\n", type);
//			            *value = 0;
			        break;
			}
			cur.position  += length;

			sym.leafs ~= leafString;
		}

		return sym;
	}

	// sstGlobalTypes - global type list
	void parseGlobalTypes( inout DataCursor cur )
	{
		// data pointer
//			char* ptr 		= cur.data.ptr;
		// read header
//			CVGlobalTypesTable*	hdr = cast(CVGlobalTypesTable*)ptr;
//			ptr += CVGlobalTypesTable.sizeof;

		// read header
		CVGlobalTypesTable*	hdr = cast(CVGlobalTypesTable*)cur.ptr;
		cur.position += CVGlobalTypesTable.sizeof;

		/*
		// get number of type records
		uint flags		= *cast(uint*)ptr;	ptr += uint.sizeof;

		// get number of type records
		uint numTypes	= *cast(uint*)ptr;	ptr += uint.sizeof;
		*/

		// get type record offset table
		uint* offsets	= cast(uint*)cur.ptr;
		cur.position += uint.sizeof * hdr.numTypes;

		// save offset table base
		uint base = cur.position;

		// parse type records
		for( uint i = 0; i < hdr.numTypes; i++ )
		{
			// set offset & calculate ptr
			cur.position = base + offsets[i];

			//assert( (recordBase + offsets[i]) == ( cur.ptr ) );

			// parse a type string
			SymbolTypeDef sym 	= parseTypeString( cur );

			// store typedef in map
			sym.index			= 0x1000 + i;
			types[sym.index] 	= sym;			// master symbol type map
		}

	}

	// sstLibraries - library list
	void parseLibrariesEntry( inout DataCursor cur )
	{
		char* ptr = cur.data.ptr;

		assert( *cast(byte*)ptr == 0 );
//			lib.length = *cast(byte*)ptr;
		ptr += byte.sizeof;	// skip past first 0 length string
//			memcpy( lib.ptr, ptr, lib.length );
//			ptr += lib.length;

		uint nLength;
		while( (nLength = *cast(byte*)ptr) != 0 )
		{
			ptr += byte.sizeof;

			char[] lib;
			lib.length = nLength;
			memcpy( lib.ptr, ptr, nLength );
			ptr += nLength;

			libs ~= lib;
			if( verbose )
				writefln("\t\t\t\tlib: ", lib );
		}
	}

	// sstModule - modules
	void parseModuleEntry( inout DataCursor cur )
	{
		char* ptr 		= cur.data.ptr;

		// grab module header
		CVModuleEntry* hdr	= cast(CVModuleEntry*)ptr;	ptr += CVModuleEntry.sizeof;

		// verify style
		assert( hdr.style == 0x5643 );	 // 'CV'

		// create symbol module
		SymbolModule mod = new SymbolModule;

		// grab segment infos
		for( uint i = 0; i < hdr.segmentCount; i++ )
		{
			BinarySectionInfo info;
			CVSegInfo* seg = cast(CVSegInfo*)ptr;
			ptr += CVSegInfo.sizeof;

			info.index 			= seg.segment;
			info.offset		 	= seg.offset;
			info.size 			= seg.size;
			mod.sectionInfos	~= info;
		}

		// module name
		mod.name.length = *cast(byte*)ptr;
		ptr += byte.sizeof;
		memcpy( mod.name.ptr, ptr, mod.name.length );
		ptr += mod.name.length;

		// place module into array & map
		moduleMap[mod.name]	= mod;

		sourceModules		~= mod;


		// debug (DDL) print
		if( verbose )	
			writefln( "\t\t\t\t%s - overlay: %d, library: %d, segs: %d, style: %d", mod.name, hdr.overlay, hdr.library, hdr.segmentCount, hdr.style );
		foreach( BinarySectionInfo info; mod.sectionInfos )
		{
			if( verbose )
				writefln( "\t\t\t\t\tseg: %d, offset: %d, size: %d", info.index, info.offset, info.size );
		}
	}

	// sstSrcModules - source files and line numbers
	void parseSrcModule( inout DataCursor cur, SymbolModule mod=null )
	{

//			uint filePos = entry.FileOffset + debugOffset;
//			uint startPos = entry.FileOffset + debugOffset;
//			file.position = startPos;

//			ushort cFile;	// = *cast(ushort*)ptr;
//			file.read( cFile );

		char* pModule 	= cur.data.ptr;
		char* ptr 		= cur.data.ptr;

//			CVSrcModuleHeader* hdr = cast(CVSrcModuleHeader*) data.ptr;
//			ptr += CVSrcModuleHeader.sizeof;

		// grab header & pointers
		CVSrcModule* hdr		= cast(CVSrcModule*)ptr;	ptr += CVSrcModule.sizeof;
		uint*	pBaseSrcPtrs	= cast(uint*)ptr;			ptr += uint.sizeof * hdr.numFiles;
		uint*	pBaseSegPairs	= cast(uint*)ptr; 			ptr += uint.sizeof * hdr.numSegs * 2;
		ushort*	pBaseSegs		= cast(ushort*)ptr;			ptr += ushort.sizeof * hdr.numSegs;

		// pad
		if( (hdr.numSegs & 1) != 0 )
			ptr += 2;

//			ushort cFile = *cast(ushort*) ptr;
//			ptr += ushort.sizeof;

//			ushort cSegInMod = *cast(ushort*) ptr;
//			ptr += ushort.sizeof;
//			file.read( cSegInMod );
		if( verbose )
			writefln( "source files in module: ", 	hdr.numFiles );
		if( verbose )
			writefln( "segments in module: ", 		hdr.numSegs );

		uint fileTableOffset;
		//file.position = ptr + i * uint.sizeof;
		// store file position
//			uint pos = file.position;

		// read filetable offsets
//			uint[] files;
//			files.length = hdr.numFiles;
//			memcpy( files.ptr, ptr, files.length * uint.sizeof );
//			ptr += files.length * uint.sizeof;

		// read segments
//			uint[2][]	segs;

//			file.readExact( files.ptr, files.length*uint.sizeof );

		// print segments
		uint* pCurBasePair = pBaseSegPairs;
		for( uint qs = 0; qs < hdr.numSegs; qs++ )
		{
			if( verbose )
				writefln( "\tsegment: 0x08%x - 0x08%x", pCurBasePair[0], pCurBasePair[1] );
			pCurBasePair += 2;
		}

//		uint[]		begin;
//		uint[]		end;

		// print files
		for( ushort f = 0; f < hdr.numFiles; f++ )
		{
			//	Goto the data for this source file
			ptr = cur.data.ptr + pBaseSrcPtrs[f];

			//	Get the name, line and segment information for this file
			ushort	NumSegs		= *cast(ushort*)ptr;	ptr += ushort.sizeof;
			ushort	Pad			= *cast(ushort*)ptr;	ptr += ushort.sizeof;
			uint*	pSrcLines	= cast(uint*)ptr;		ptr += uint.sizeof * NumSegs;
			uint*	pSegPairs	= cast(uint*)ptr;		ptr += uint.sizeof * NumSegs * 2;
			ubyte	FNameLen	= *cast(ubyte*)ptr; 	ptr += ubyte.sizeof;
			char*	pFName		= cast(char*)ptr;		ptr += FNameLen;

			char[] fileName;
			if( (fileName.length = FNameLen) != 0 )
				memcpy( fileName.ptr, pFName, fileName.length );

			if( verbose )
				writefln( "\tfile: %s - %d segments", fileName, NumSegs );

			// get symbol module
//				SymbolModule mod = modules[$];

			// create symbol module
//				SymbolModule mod 	= new SymbolModule;

			// setup symbol module
			mod.sourceFile 		= fileName;

			// put module into source code map
			sourceMap[fileName] = mod;

			// segments
			uint* pCurPair = pSegPairs;
			for( uint seg = 0; seg < NumSegs; seg++ )
			{
				// set module limits
				mod.begin 	~= pCurPair[0];
				mod.end 	~= pCurPair[1];

				if( verbose )
					writefln( "\t\tseg %d: 0x%08x - 0x%08x", seg+1,  pCurPair[0], pCurPair[1] );
				pCurPair += 2;
			}

//				assert( ( fileName in modules[fileName] ) is null );
//				if( ( fileName in modules[fileName] ) is null )


			// add lines and addresses
			for( uint seg = 0; seg < NumSegs; seg++ )
			{
				ubyte*	tmpPtr		= cast(ubyte*)(pModule + pSrcLines[seg]);
				ushort	Seg			= *cast(ushort*)tmpPtr;	tmpPtr += ushort.sizeof;
				ushort	lineCount	= *cast(ushort*)tmpPtr;	tmpPtr += ushort.sizeof;
				uint*	offsets		= cast(uint*)tmpPtr;	tmpPtr += uint.sizeof * lineCount;
				ushort*	lines		= cast(ushort*)tmpPtr;	tmpPtr += ushort.sizeof * lineCount;
//					if( verbose ) writefln( "\t\tline %d: seg: %d lines: %d", seg+1,  Seg, lineCount );

				// add lines
				for( int o = 0; o < lineCount; o++ )
				{
					// place line & address into module maps
					mod.lineMap[offsets[o]] = lines[o];
					mod.addrMap[lines[o]] = offsets[o];
//						if( verbose ) writefln( "\t\t\tline: %d address: 0x%08x", lines[o],  offsets[o] );
				}
			}

			// refresh sorted lists
			mod.refresh();

		}
	}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// source location management
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// return next available line
	uint findNextLine( uint line, char[] file )
	{
		// find source module
		SymbolModule* mod = file in sourceMap;		// sstSrcModule -> map source files to modules
		// call source module
		return mod ? mod.findNextLine( line ) : 0;
	}


	// get an address from a source location
	uint addressFromSource( uint line, char[] srcFile )
	{
		// find source module
		SymbolModule* mod = srcFile in sourceMap;		// sstSrcModule -> map source files to modules
		if( !mod )
			return 0;

		// grab address
		uint address = mod.address(line);

		// convert offset to memory address
		return codeOffsetToAddress( address );
	}

	uint addressFromSource( SourceLocation* loc )
	{
		return addressFromSource( loc.line, loc.file );
	}


// get source location from an address
	SourceLocation* sourceFromAddress( uint addr )
	{
		uint nAddress = addr;

		// calculate section offset from the virtual address of executable code section.
		if( exeSection )
			nAddress = addr - (imageBase + exeSection.VirtualAddress);

//			msgBox( format( "looking for 0x%08x (%x - %x)", nAddress,addr,exeSection.VirtualAddress) );
//			if( verbose ) writefln( "looking for 0x%08x (%x - %x)", nAddress,addr,exeSection.VirtualAddress);

		// msgBox( format( "image base %x\n", imageBase )  ~ format( "code section %x\n", exeSection.VirtualAddress ) ~ format( "address %x -> %x\n", addr, nAddress ) );
		foreach( SymbolModule mod; sourceMap )
		{
			// check if address is in module
			if( mod.isInAddress(nAddress) )
			{

				//msgBox( format( "found %x : [%x - %x]\n", nAddress, mod.begin[0], mod.end[0] ) );
				// find line location from module
				SourceLocation* loc = new SourceLocation;
				loc.file = mod.sourceFile;
				loc.line = mod.lineFromAddress(nAddress);
//					if( verbose ) msgBox( format( "line ", loc.line ) );
//					if( verbose ) writefln( "line ", loc.line );
				return loc;
			}
		}

		return null;
	}

// lookup function
	Symbol findFunction( uint Address )
	{
		return null;
	}

	Symbol findData( uint Address )
	{
		return null;
	}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////
// address conversion - convert between a memory address and an offset into the executable code
///////////////////////////////////////////////////////////////////////////////////////////////////////////////

	// memory address -> code section offset
	uint addressToCodeOffset( uint addr )
	{
		if( exeSection )
			return addr - (imageBase + exeSection.VirtualAddress);
		return addr - imageBase;
	}

	// code section offset -> memory address
	uint codeOffsetToAddress( uint addr )
	{
		if( exeSection )
			return addr + (imageBase + exeSection.VirtualAddress);
		return addr + imageBase;
	}


} // class SymbolModule

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// codeview primitive type -> DATATYPE conversion
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

DATATYPE convertCVType( uint type )
{
	if( type >= 0x1000 )
		return cast(DATATYPE)type;

	switch( type )
	{
	// 32-bit real
		case T_REAL32:	return DATATYPE.Float;
		case T_PREAL32:	return DATATYPE.FloatPtr;

	// 8-bit integer
		case T_CHAR:	return DATATYPE.Int8;
		case T_UCHAR:	return DATATYPE.UInt8;
		case T_PCHAR:	return DATATYPE.Int8Ptr;
		case T_PUCHAR:	return DATATYPE.UInt8Ptr;

	// 16-bit integer
		case T_INT2:	return DATATYPE.Int16;
		case T_UINT2:	return DATATYPE.UInt16;
		case T_PINT2:	return DATATYPE.Int16Ptr;
		case T_PUINT2:	return DATATYPE.UInt16Ptr;

	// 32-bit integer
		case T_INT4:	return DATATYPE.Int32;
		case T_UINT4:	return DATATYPE.UInt32;
		case T_PINT4:	return DATATYPE.Int32Ptr;
		case T_PUINT4:	return DATATYPE.UInt32Ptr;

	// 64-bit integer
		case T_QUAD:	return DATATYPE.Int64;
		case T_UQUAD:	return DATATYPE.UInt64;
		case T_PQUAD:	return DATATYPE.Int64Ptr;
		case T_PUQUAD:	return DATATYPE.UInt64Ptr;

	// unhandled type
		default:
//			msgBoxf( "unhandled data type: 0x%04x", type );
			return DATATYPE.Unknown;
	}

	return DATATYPE.Unknown;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parse a numeric leaf value
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

int parseNumericLeaf( inout DataCursor cur )
{
	ushort type	= cur.parseUSHORT();

	//
    if( type < LF_NUMERIC )
        return type;

	// msgBoxf( "numeric leaf: 0x%04x = %s", type, CVTypeToString( type ) );

    switch (type)
    {
        case LF_CHAR:
        	return cast(int) cur.parseBYTE();

        case LF_SHORT:
        	return cast(int) cur.parseSHORT();

        case LF_USHORT:
        	return cast(int) cur.parseUSHORT();

        case LF_LONG:
        	return cast(int) cur.parseINT();

        case LF_ULONG:
        	return cast(int) cur.parseUINT();

		// TO DO: finish implementing types
        case LF_QUADWORD:
        case LF_UQUADWORD:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 8;
            break;

        case LF_REAL32:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 4;
            break;

        case LF_REAL48:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 6;
            break;

        case LF_REAL64:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 8;
            break;

        case LF_REAL80:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 10;
            break;

        case LF_REAL128:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 16;
            break;

        case LF_COMPLEX32:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 4;
            break;

        case LF_COMPLEX64:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 8;
            break;

        case LF_COMPLEX80:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 10;
            break;

        case LF_COMPLEX128:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
            cur.position += 16;
            break;

        case LF_VARSTRING:
    		throw new Exception( format("Unsupported numeric leaf type %04x\n", type) );
			int len = cur.parseINT();
            cur.position += 2 + len;
            break;

        default:
		    throw new Exception( format("Unknown numeric leaf type %04x\n", type) );
            break;
    }
	return 0;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CodeView leaf to string
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

char[] leafToString( ushort leaf )
{
	switch( leaf )
	{
	// symbol leafs
        case LF_MODIFIER_V1:	return "modifier";
        case LF_POINTER_V1:		return "pointer";
        case LF_ARRAY_V1:		return "array";
        case LF_CLASS_V1:		return "class";
        case LF_STRUCTURE_V1:	return "structure";
        case LF_UNION_V1:		return "union";
        case LF_ENUM_V1:		return "enum";
        case LF_PROCEDURE_V1:	return "procedure";
        case LF_MFUNCTION_V1:	return "mfunction";
        case LF_VTSHAPE_V1:		return "vtshape";
        case LF_COBOL0_V1:		return "cobol0";
        case LF_COBOL1_V1:		return "cobol1";
        case LF_BARRAY_V1:		return "barray";
        case LF_LABEL_V1:		return "label";
        case LF_NULL_V1:		return "null";
        case LF_NOTTRAN_V1:		return "nottran";
        case LF_DIMARRAY_V1:	return "dimarray";
        case LF_VFTPATH_V1:		return "vftpath";
        case LF_PRECOMP_V1:		return "precomp";
        case LF_ENDPRECOMP_V1:	return "endprecomp";
        case LF_OEM_V1:			return "OEM";
        case LF_TYPESERVER_V1:	return "modifier";

	// type-record leafs
		case LF_SKIP_V1:		return "skip";
		case LF_ARGLIST_V1:		return "arglist";
		case LF_DEFARG_V1:		return "defarg";
		case LF_LIST_V1:		return "list";
		case LF_FIELDLIST_V1:	return "feildlist";
		case LF_DERIVED_V1:		return "derived";
		case LF_BITFIELD_V1:	return "bitfield";
		case LF_METHODLIST_V1:	return "methodlist";
		case LF_DIMCONU_V1:		return "dimconu";
		case LF_DIMCONLU_V1:	return "dimconlu";
		case LF_DIMVARU_V1:		return "dimvaru";
		case LF_DIMVARLU_V1:	return "dimvarlu";
		case LF_REFSYM_V1:		return "refsym";

	// numeric leafs
        case LF_CHAR:			return "char";
        case LF_SHORT:			return "short";
        case LF_USHORT:			return "ushort";
        case LF_LONG:			return "int";
        case LF_ULONG:			return "uint";
        case LF_QUADWORD:		return "long";
        case LF_UQUADWORD:		return "ulong";
        case LF_REAL32:			return "float";
        case LF_REAL48:			return "real48";
        case LF_REAL64:			return "real64";
        case LF_REAL80:			return "real80";
        case LF_REAL128:		return "real128";
        case LF_COMPLEX32:		return "complex32";
        case LF_COMPLEX64:		return "complex64";
        case LF_COMPLEX80:		return "complex80";
        case LF_COMPLEX128:		return "complex128";
        case LF_VARSTRING:		return "varstring";

	// field leafs
		case LF_BCLASS_V1:		return "baseclass";
		case LF_VBCLASS_V1:		return "direct virtual baseclass";
		case LF_IVBCLASS_V1:	return "indirect virtual baseclass";
		case LF_ENUMERATE_V1:	return "enumerate";
		case LF_FRIENDFCN_V1:	return "friend func";
		case LF_INDEX_V1:		return "type index";
		case LF_MEMBER_V1:		return "data";
		case LF_STMEMBER_V1:	return "static data";
		case LF_METHOD_V1:		return "method";
		case LF_NESTTYPE_V1:	return "nested type";
		case LF_VFUNCTAB_V1:	return "virtual function table";
		case LF_FRIENDCLS_V1:	return "friend class";
		case LF_ONEMETHOD_V1:	return "one method";
		case LF_VFUNCOFF_V1:	return "virtual function offset";
		case LF_NESTTYPEEX_V1:	return "nested typeex";
		case LF_MEMBERMODIFY_V1: return "member modify";

	    default:				return format( "unknown leaf 0x%x", leaf );
	}
	return "unknown";
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parse a fieldlist leaf into a symbol member
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

CodeViewField parseFieldLeaf( inout DataCursor cur )
{
	CodeViewField field;
	ushort fieldLeaf = cur.parseUSHORT();
	switch( fieldLeaf )
	{
		case LF_BCLASS_V1:
			field.type			= memberBASE;
			field.baseType		= cur.parseUSHORT();
			field.baseAttrib	= cur.parseUSHORT();
			field.baseOffset 	= parseNumericLeaf(cur);
			break;

		case LF_ENUMERATE_V1:
			field.type			= memberENUM;
			field.enumAttrib	= cur.parseUSHORT();
			field.enumValue 	= parseNumericLeaf(cur);
			field.name			= _parseString( cur );
			//msgBoxf("member enum - %s = %d", field.name, field.enumValue );
			break;

		// type index
		case LF_INDEX_V1:
			field.type		= memberINDEX;
			field.indexType	= cur.parseUSHORT();
			assert( field.indexType > 0x1000 );
			break;

		// data member
		case LF_MEMBER_V1:
			field.type			= memberDATA;
			field.dataType 		= cur.parseUSHORT();
			field.dataAttrib	= cur.parseUSHORT();
        	field.dataOffset	= cast(uint)parseNumericLeaf( cur );
			field.name			= _parseString( cur );
			break;

		// static data mebmer
		case LF_STMEMBER_V1:
			field.type			= memberSTATICDATA;
			field.dataType 		= cur.parseUSHORT();
			field.dataAttrib	= cur.parseUSHORT();
			field.name			= _parseString( cur );
//			assert( field.dataType > 0x1000 );
			break;

		// method function
		case LF_METHOD_V1:
			field.type			= memberMETHOD;
			field.methodCount 	= cur.parseUSHORT();
			field.methodList 	= cur.parseUSHORT();
			field.name			= _parseString( cur );
//			assert( field.methodList > 0x1000 );
//			msgBoxf( "LF_METHOD_V1: %s 0x%0x - count %d", field.name, field.methodList, field.methodCount );
			break;

		// nested type
		case LF_NESTTYPE_V1:
			field.type			= memberNESTEDTYPE;
			field.nestedType	= cur.parseUSHORT();
			field.name			= _parseString( cur );
			assert( field.nestedType > 0x1000 );
			break;

		// currently unhandled leaf fields
		case LF_VFUNCTAB_V1:
		case LF_FRIENDCLS_V1:
		case LF_ONEMETHOD_V1:
		case LF_VFUNCOFF_V1:
		case LF_NESTTYPEEX_V1:
		case LF_MEMBERMODIFY_V1:
		case LF_VBCLASS_V1:
		case LF_IVBCLASS_V1:
		case LF_FRIENDFCN_V1:
			throw new Exception( format( "unhandled field %s\nthis must be implemented to continue parsing this file", leafToString(fieldLeaf) ) );
			assert( false );	// implement the parser
			break;

		default:
			throw new Exception( format( "error - unknown field leaf: 0x%04x", fieldLeaf ) );
			break;
	}
	return field;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// write out codeview data structures
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void writeCV4( in CVSubSection entry )
{
	writefln(
		"\n\t\t\tCodeView Section Entry:\n"
		"\t\t\t\tSubsection Type: %d\n"
		"\t\t\t\tMod: %d\n"
		"\t\t\t\tFile Offset: %08X\n"
		"\t\t\t\tSize: %d\n",
		entry.SubsectionType,
		entry.iMod,
		entry.FileOffset,
		entry.Size);

}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// symbol type
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

enum : uint
{
	typeUNKNOWN,		// unknown
	typeNUMBER,			// number
	typeMODIFIER,		// modifier
	typeARGLIST,		// argument list
	typePROCEDURE,		// procedure
	typePOINTER,		// pointer
	typeARRAY,			// array definition
	typeCLASS,			// class definition
	typeSTRUCT,			// struct definition
	typeFIELDLIST,		// class/struct field list
	typeMETHODLIST,		// method list
	typeENUM,			// enum definition
	typeUNION,			// union definition
	typeMEMFUNC,		// member function
	typeDERIVED,		// derived type
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// codeview 4 typedef
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct SymbolTypeDef
{
	ushort		index;		// type index
	char[]		name;		// name - if exists
	uint		size;

	uint 		type;		// type - determines which union is active
	char[]		typeString;	// type string


	char[][] 	leafs;		// array of leaf strings

	// specific types
	union
	{
		// typeMODIFIER
		struct
		{
			ushort	modifierAttrib;
			ushort	modifierType;
		}

		// typePOINTER
		struct
		{
			ushort	pointerType;
			ushort	pointerAttrib;
			ushort	pointerMode;

		}

		// typeARRAY
		struct
		{
			ushort	arrayType;
			ushort	arrayIndex;
			ushort	arraySize;
		}

		// typePROCEDURE
		struct
		{
			ushort	procedureReturnType;
			ushort	procedureArglist;
			ushort	procedureCalling;
			ushort 	procedureParams;
		}

		// typeCLASS / typeSTRUCT
		struct
		{
			ushort	structLeafCount;
			ushort	structFieldList;
			ushort	structFlags;
			ushort	structDerivationList;
			ushort	structVShape;
		}

		// typeFIELDLIST
		struct
		{
			CodeViewField[] fieldList;
		}

		// typeARGLIST
		struct
		{
			ushort[] arglist;
			char[] argString;
		}

		// typeENUM
		struct
		{
			ushort	enumCount;
			ushort	enumType;
			ushort	enumList;
			ushort	enumFlags;
		}

		// typeMEMFUNC
		struct
		{
			ushort	memfuncReturnType;
			ushort	memfuncClassType;
			ushort	memfuncThisIndex;
			ubyte	memfuncCalling;
			ushort	memfuncArgCount;
			ushort	memfuncArgList;
			uint	memfuncThisAdjust;
		}

		// typeMETHODLIST
		struct
		{
			SymbolMethod[]	methodList;
		}

		// type UNION
		struct
		{
        	ushort 	unionCount;
        	ushort 	unionListIndex;
        	ushort 	unionProperties;
        	uint	unionSize;

		}
		
		// typeDERIVED
		struct
		{
			ushort[] 	derivedList;
		}

	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// class/struct member type
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

enum : uint
{
	memberUNKNOWN,
	memberINDEX,
	memberMETHOD,
	memberDATA,
	memberSTATICDATA,
	memberENUM,
	memberBASE,
	memberNESTEDTYPE,
}

// class/struct method definition
struct SymbolMethod
{
	ushort	attributes;
	ushort	type;
	ushort	virtualOffset;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// class/struct/enum field definition
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct CodeViewField
{
	char[]	name;
	uint	type;	// field type

	union
	{
		// memberINDEX
		struct
		{
			ushort indexType;
		}

		// memberNESTEDTYPE
		struct
		{
			ushort nestedType;
		}

		// memberDATA & memberSTATICDATA
		struct
		{
			ushort	dataType;
			ushort	dataAttrib;
			uint	dataOffset;
		}

		// memberENUM
		struct
		{
			ushort	enumAttrib;
			ushort	enumValue;
		}

		// memberMETHOD
		struct
		{
			ushort	methodList;
			ushort	methodCount;
		}

		// memberBASE
		struct
		{
			ushort	baseType;
			ushort	baseAttrib;
			uint	baseOffset;
		}


	}

}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parse a field attribute
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

char[] setupCVFieldAttribute( SymbolClassField* field, uint attrib )
{
	char[] text;
	// access protection
	switch( attrib & FIELD_ATTRIBUTE.ACCESS_MASK )
	{
		case FIELD_ATTRIBUTE.Private:
			text = "private ";
			field.access = SYMBOL_ACCESS.Private;
			break;
		case FIELD_ATTRIBUTE.Protected:
			text = "protected ";
			field.access = SYMBOL_ACCESS.Protected;
			break;
		case FIELD_ATTRIBUTE.Public:
			text = "public ";
			field.access = SYMBOL_ACCESS.Public;
			break;
		default:
			field.access = SYMBOL_ACCESS.None;
			break;
	}

	// parse properties
	switch( ( attrib >> FIELD_ATTRIBUTE.PROP_SHIFT ) & FIELD_ATTRIBUTE.PROP_MASK )
	{
		case FIELD_ATTRIBUTE.Vanilla: 			// Vanilla method
			break;
		case FIELD_ATTRIBUTE.Virtual: 			// Virtual method
			text ~= "virtual ";
			field.isVirtual 	= true;
			break;
		case FIELD_ATTRIBUTE.Static:			// Static
			text ~= "static ";
			field.isStatic	= true;
			break;
		case FIELD_ATTRIBUTE.Friend:			// Friend
			text ~= "friend ";
			field.isFriend	= true;
			break;
		case FIELD_ATTRIBUTE.Introducing:		// Introducing virtual
			text ~= "virtual ";
			field.isVirtual 	= true;
			break;
		case FIELD_ATTRIBUTE.PureVirtual:		// Pure virtual
			text ~= "pure ";
			field.isVirtual 	= true;
			break;
		case FIELD_ATTRIBUTE.PureVirtualIntro:	// Pure introducing virtual
			text ~= "pure ";
			field.isVirtual 	= true;
			break;
	}

	return text;
}

/*
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parse codeview types into symbol typedefs
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

bit parseCodeViewSymbols( inout SymbolManager symbolManager, CodeViewData codeView )
{
	int typeCount 	= codeView.types.length;
	int maxType 	= typeCount + 0x1000;

	if( codeView.verbose )
		writefln( "parsing codeview data into symbols - %d", codeView.types.length );

	// set code section
	//symbolManager.codeSection = codeView.codeSection;

	// place symbol modules into symbol manager
	foreach( SymbolModule mod; codeView.modules )
	{
		symbolManager.modules ~= mod;
	}

	// process top-level symbol types & create typedefs
	foreach( ushort idx, SymbolTypeDef sym; codeView.types )
	{
		try {

		assert( idx == sym.index );

	// enum definition
		if( sym.type == typeENUM )
		{
			if( codeView.verbose )
				writefln( "0x%04x\tenum %s : %s - 0x%04x", sym.index, sym.name, CVTypeToString(sym.enumType), sym.enumList );

			// verify enum list index
			assert( sym.enumList >= 0x1000 );
			assert( sym.enumList <= maxType );
			if(( sym.enumList < 0x1000 ) || (sym.enumList > maxType))
				continue;

			// create the enum def
			SymbolEnumDef def = parseCodeView_EnumSymbol( sym, symbolManager, codeView );

			// add to lists
			symbolManager.typeIndexMap[def.index]	= def;
			symbolManager.enumDefs ~= def;
			symbolManager.typeDefs ~= def;
		}

	// class/struct typedefs
		else if(( sym.type == typeCLASS ) || ( sym.type == typeSTRUCT ))
		{
			if( ( sym.structFlags & CV_CLASSDEF_PROPERTIES.ForwardRef ) != 0 )
				continue;
		//					assert( sym.structFieldList >= 0x1000 );
		//					assert( sym.structFieldList <= maxType );
			// verify fieldlist index
//			msgBoxf( sym.structFieldList );
//			assert(( sym.structFieldList == 0 ) || (( sym.structFieldList >= 0x1000 ) && ( sym.structFieldList <= maxType )));
//			if(( sym.structFieldList < 0x1000 ) || ( sym.structFieldList > maxType ))
//				continue;
			// create the class def
			SymbolClassDef def = parseCodeView_ClassDef( sym, symbolManager, codeView );
			if( codeView.verbose )
			{
				writefln( "0x%04x\tstruct %s", sym.index, sym.name );
				writefln( "\t\tfield list: 0x%04x", sym.structFieldList );
				writef( "\t\tflags: " );
				if( def.isForwardRef )		writef( "forward ref, " );
				if( def.isPacked )			writef( "packed, " );
				if( def.isNested )			writef( "nested, " );
				if( def.hasNested )			writef( "has nested, " );
				if( def.hasCtor )			writef( "has ctor, " );
				if( def.hasOverloadedOps )	writef( "overloaded ops, " );
				if( def.hasOpAssign )		writef( "op assign, " );
				if( def.hasOpCast )			writef( "op cast, " );
				if( def.isScoped )			writef( "is scoped " );
				writefln( "\n\t\tderivation list: 0x%04x", sym.structDerivationList );
			}
			// add to lists
			symbolManager.typeIndexMap[def.index]	= def;
			symbolManager.classDefs ~= def;
			symbolManager.typeDefs 	~= def;
		}
		else if( sym.type == typeDERIVED )
		{
//			if( verbose ) writefln( "0x%04x\tderivation list", sym.index  );
//			foreach( uint ii, ushort d; sym.derivedList )
//				writefln( "\t%d - 0x%04x", ii, d );
		}
		else
		{
			if( codeView.verbose )
				writefln( "0x%04x - %s %s", sym.index, sym.name, leafToString(sym.type) );
		}

		}
		catch( Object e )
		{
			writefln( "exception: " ~ e.toString );
		}
	}

	// post-process class defs
	foreach( SymbolClassDef def; symbolManager.classDefs )
	{
		// resolve base classes
		if( def.baseType )
		{
			if( def.baseType < 0x1000 )
				continue;

//			assert( def.baseType >= 0x1000 );
			assert( def.baseType <= ( 0x1000 + codeView.types.length ));
			SymbolTypeDefinition* baseDef = def.baseType in symbolManager.typeIndexMap;
			if( baseDef )
			{
				def.baseClass	= cast(SymbolClassDef) *baseDef;
				if( def.baseClass.name == "Object" )
				{
					def.text = format( "class %s", def.name );
				}
				else
				{
					def.text = format( "class %s : %s", def.name, def.baseClass.name );
				}
			}
			else
			{
				def.text = format( "class %s", def.name );
			}
		}
		else if( def.name == "Object" )
		{
			def.text = format( "class Object" );
		}
		else
		{
			def.text = format( "struct %s", def.name );
		}
	}


	// success
	return true;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// create enum definition
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SymbolEnumDef parseCodeView_EnumSymbol( SymbolTypeDef sym, inout SymbolManager symbolManager, CodeViewData codeView )
{
	// process class typedef
	SymbolEnumDef def 	= new SymbolEnumDef;
	def.name 			= sym.name;
	def.index 			= sym.index;
	def.flags 			= sym.enumFlags;
	def.type 			= sym.enumType;

	// grab enum field list
	SymbolTypeDef field = codeView.types[sym.enumList];
	assert( field.index == sym.enumList );
	assert( field.type == typeFIELDLIST );
	if( field.type == typeFIELDLIST )
	{
		// parse enum values
		foreach( CodeViewField member; field.fieldList )
		{
			assert( member.type == memberENUM );
			// enum value
			if( member.type == memberENUM )
			{
				// create enum value
				SymbolEnum value;
				value.name		= member.name;
				value.value 	= member.enumValue;
				value.attribute	= member.enumAttrib;

				// add value to enum definition
				def.values ~= value;
			}
			else
			{
				assert( false );
			}
		}
	}

	return def;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// create class/structure definition
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SymbolClassDef parseCodeView_ClassDef( SymbolTypeDef sym, inout SymbolManager symbolManager, CodeViewData codeView )
{
//	int typeCount 	= codeView.types.length;
//	int maxType 	= typeCount + 0x1000;
	// verify codeview typedef
	assert( (sym.type == typeCLASS) || (sym.type == typeSTRUCT) );

	// create class type definition
	SymbolClassDef def 	= new SymbolClassDef;
	def.name 			= sym.name;
	def.index 			= sym.index;
	def.size			= sym.size;
	def.isClass 		= sym.type == typeCLASS;

	// process property flags
	def.isPacked 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.Packed ) != 0;
	def.isForwardRef 		= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.ForwardRef ) != 0;
	def.isNested 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.IsNested ) != 0;
	def.hasNested 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.ContainsNested ) != 0;
	def.hasCtor 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.Ctor ) != 0;
	def.hasOverloadedOps 	= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.Overops ) != 0;
	def.hasOpAssign 		= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.OpAssign ) != 0;
	def.hasOpCast 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.OpCast ) != 0;
	def.isScoped 			= ( sym.structFlags & CV_CLASSDEF_PROPERTIES.Scoped ) != 0;

	// process fieldlist
	if( sym.structFieldList != 0 )
	{
//		if(( sym.structFieldList < 0x1000 ) || ( sym.structFieldList > maxType ))
//			continue;
		assert( sym.structFieldList >= 0x1000 );
		assert( sym.structFieldList <= codeView.types.length + 0x1000 );

		// grab fieldlist
		SymbolTypeDef fieldList = codeView.types[sym.structFieldList];
		assert( fieldList.index == sym.structFieldList );
	//	msgBoxf( "field name (0x%04x) %s - %d", sym.structFieldList, field.name, field.type );
	//	msgBoxf( "field error (0x%04x)", sym.structFieldList );
		assert( fieldList.type == typeFIELDLIST );

		// process class member list
		if( fieldList.type == typeFIELDLIST )
		{
			// parse class/struct fields
			foreach( CodeViewField field; fieldList.fieldList )
			{
	//			uint methodIndex = 0;
				// grab the method typedef
	//			SymbolTypeDef method = codeView.types[methodIndex];

				// add symbol class methods
				switch( field.type )
				{
					// class data field
					case memberDATA:

						SymbolClassMember mem = new SymbolClassMember;
						mem.name		= field.name;
						mem.type		= field.dataType;
						mem.offset		= field.dataOffset;

						// parse field attribute
						char[] callingString = setupCVFieldAttribute( cast(SymbolClassField*)mem, field.dataAttrib );

						// custom type
						char[] typeName = CVTypeToString( mem.type ).dup;
						if( mem.type >= 0x1000 )
							typeName = codeView.types[mem.type].name;
	
						mem.text 		= format( "%s%s %s", callingString, typeName, mem.name );
						def.members		~= mem;
						def.fields 		~= mem;
						break;
	
					// class method list
					case memberMETHOD:

						assert( field.methodList >= 0x1000 );
						assert( field.methodList <= codeView.types.length + 0x1000 );
						if(( field.methodList > codeView.types.length + 0x1000 ) || ( field.methodList < 0x1000 ))
							break;
	
						// grab method list
						SymbolTypeDef methodList = codeView.types[field.methodList];
						assert( methodList.index == field.methodList );
						assert( methodList.type == typeMETHODLIST );
	
	//					msgBoxf( "methodlist: %s - %d", field.name, methodList.methodList.length );
	
						// loop through method instance list
						foreach( SymbolMethod method; methodList.methodList )
						{
							int methodType = method.type;
	
							//if(( methodType < 0x1000 ) || ( methodType > codeView.types.length + 0x1000 ))
							//	msgBoxf( "invalid method type: %x attrib: %x offset: %x", method.type, method.attributes, method.virtualOffset );
	
							// check proc def type
							if( methodType < 0x1000 )
								continue;
							if( methodType == 0 )
								continue;
							if( methodType > codeView.types.length + 0x1000 )
								continue;
	//										assert( method.type <= codeView.types.length + 0x1000 );
	//										assert( method.type >= 0x1000 );
	
	//										msgBoxf( "valid method type: %x attrib: %x offset: %x", method.type, method.attributes, method.virtualOffset );

	
							// grab method def
							SymbolTypeDef procDef = codeView.types[method.type];
							//msgBoxf( "invalid method.type: 0x%04x", method.type );

							if( procDef.type != typeMEMFUNC )
							{
								msgBoxf( "invalid procdef: 0x%04x - %d", cast(uint)method.type, cast(uint)procDef.type );
								continue;
							}
	
						//	msgBoxf( "valid procdef: %x attrib: %x offset: %x", method.type, method.attributes, method.virtualOffset );
	
							assert( procDef.type == typeMEMFUNC );
	
							// create class method
							SymbolClassMethod meth = new SymbolClassMethod;
							meth.name			= field.name.dup;
							meth.virtualOffset	= method.virtualOffset;
							meth.returnType 	= procDef.memfuncReturnType;
							meth.classType 		= procDef.memfuncClassType;
							meth.thisIndex 		= procDef.memfuncThisIndex;
							meth.thisAdjust 	= procDef.memfuncThisAdjust;
	
							// parse field attribute
							char[] callingString = setupCVFieldAttribute( cast(SymbolClassField*)meth, method.attributes );
	
							// parse return type
							meth.returnType 	= procDef.memfuncReturnType;
							switch( procDef.memfuncCalling )
							{
								case 0:			// near c
								case 1:			// far c
	//								callingString = "";
									break;
								case 2:			// near pascal
								case 3:			// far pascal
									callingString ~= "pascal ";
									break;
								case 4:			// near fastcall
								case 5:			// far fastcall
									callingString ~= "fastcall ";
									break;
								case 7:			// near stdcall
								case 8:			// far stdcall
									callingString ~= "stdcall ";
									break;
								case 9:			// near syscall
								case 10:		// far syscall
									callingString ~= "syscall ";
									break;
								case 11:		// this syscall
									callingString ~= "this ";
									break;
								case 12:		// mips call
									callingString ~= "mips ";
									break;
								case 13:		// mips call
									callingString ~= "generic ";
									break;
								default:
									break;
							}

							// parse this stuff
							//procDef.memfuncCalling;
							//procDef.procedureParams;

							// grab argument def
							//char[] argString;

							SymbolTypeDef argDef = codeView.types[procDef.memfuncArgList];
							if( argDef.type != typeARGLIST )
								msgBoxf( "invalid arglist: 0x%04x - %d", cast(uint)procDef.memfuncArgList, cast(uint)argDef.type );

							assert( argDef.type == typeARGLIST );
							foreach( ushort arg; argDef.arglist )
							{
								meth.argumentList ~= arg;
							}

							//msgBoxf( "%s - %s", field.name, argDef.name );
							char[] retType = CVTypeToString(meth.returnType).dup;
							meth.text 	= format( "%s%s %s%s", callingString, retType, meth.name, argDef.argString );
							// parse special attributes
							//method.attributes;
							//method.type;
							//method.virtualOffset;
							// attach method to class def
							def.methods ~= meth;
							def.fields ~= meth;
						//	msgBoxf( "valid procdef: %x attrib: %x offset: %x", method.type, method.attributes, method.virtualOffset );
						}
						break;
					case memberBASE:
					// base class definition
						def.baseType 	= field.baseType;
						def.baseAttrib	= field.baseAttrib;
						def.baseOffset	= field.baseOffset;
						break;

					case memberENUM:
						break;
					default:
						break;
				}
				//meth.returnType		= field.;
				//meth.argumentList;
				//meth.text				= field.typeString;
			}
		}

	}

	// return definition
	return def;
}
*/

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// parse a string
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

char[] _parseString( inout DataCursor cur )
{
	uint len = cur.parseUBYTE();

	if( len == 0xff )
	{
		int l0 = cur.parseUBYTE();
		len = cur.parseUSHORT();
//		writef( "( Long String: 0x%02x 0x%04x (%d) ) ", l0, len, len  );
	}
//	else writef( "( String: 0x%04x (%d) ) ", len, len  );
//	writef( " ( cursor length: %d ) ", cur.length  );

	return cur.parseString( len ).dup;
}

