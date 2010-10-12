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
	Windows PE-COFF Image class (.exe & .dll files)

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFImage;

import ddl.ExportSymbol;
import ddl.Utils;

import ddl.coff.COFF;
import ddl.coff.COFFWrite;
import ddl.coff.COFFBinary;

import std.string;
import std.stdio;
import std.c.time;
import std.stream;
import std.c.string;

import ddl.coff.CodeView;

enum DEBUGTYPE
{
    Unknown,
    None,
    Codeview
}

class DebugData
{
}

// COFF PE Image Module - DLL or EXE
class COFFImage : COFFBinary
{
<<<<<<< .mine
public:
	// module identity
	char[]					moduleFile;		// name of module file
	char[]					internal_name;	// for DLLs, how it was called at compile time
	char[]					debug_name;		// When there was a MISC debug (DDL) info section
	bool						valid = false;
=======
public:
	// module identity
	char[]					moduleFile;		// name of module file
	char[]					internal_name;	// for DLLs, how it was called at compile time
	char[]					debug_name;		// When there was a MISC debug (DDL) info section
	bit						valid = false;
>>>>>>> .r278

<<<<<<< .mine
	// file info elements
	uint					peoffset;		// offset of PE header in file
	bool						peplus;			// PE32 (false) or PE32+ (true) header
=======
	// file info elements
	uint					peoffset;		// offset of PE header in file
	bit						peplus;			// PE32 (false) or PE32+ (true) header
>>>>>>> .r278

	PEHeader*				pe;				// pointer to PE32/PE32+ Header
	PEWindowsHeader*		winpe;			// Windows specific PE32/PE32+ header
	PEDataDirectories*		datadir;		// Data Directory Tables

	CodeViewData 			codeView;		// codeview debug (DDL) data
//		SymbolManager			symbolManager;

	// export/import data
	COFFExport*[]			exports;	// the exported functions of this module if any
	PEcoff_import[]			imports;	// the imported modules and their functions if any

	// loaded image base
	uint					imageBase;
    
    // debug (DDL) data
    DEBUGTYPE debugType;
    byte[] debugData;

<<<<<<< .mine
    this()
	{
		type = COFF_TYPE.IMAGE;
	}
/*
	this( DataCursor cur, char[] filename )
	{
		type = COFF_TYPE.IMAGE;
		moduleFile = filename;
		valid = loadFromFile( filename );
	}
*/
// load from file
	bool loadFromFile( char[] filename )
	{
		moduleFile 	= filename;
		valid 		= false;

		// print debug (DDL) output
		if( verbose ) writefln( "File: %s\nFile type: PECOFF MODULE\n", filename );

		// open & parse the file
		File file = new File(filename);
		if( !file.isOpen )
=======
    this()
	{
		type = COFF_TYPE.IMAGE;
	}
/*
	this( DataCursor cur, char[] filename )
	{
		type = COFF_TYPE.IMAGE;
		moduleFile = filename;
		valid = loadFromFile( filename );
	}
*/
// load from file
	bit loadFromFile( char[] filename )
	{
		moduleFile 	= filename;
		valid 		= false;

		// print debug (DDL) output
		if( verbose ) writefln( "File: %s\nFile type: PECOFF MODULE\n", filename );

		// open & parse the file
		File file = new File(filename);
		if( !file.isOpen )
>>>>>>> .r278
		{
			writefln( "unable to open file: ", filename );
		 	return false;
		}

		// catch read exceptions
		try
		{
			valid = parse( file );
		}
		catch( Exception e )
		{
			writefln( "read exception: " ~ e.toString );
		}

<<<<<<< .mine
		// close the file
		file.close();
		return valid;
	}
	
// 	bool parse( COFFReader reader )
// 	{
// 		if( !parseDOSHeader( reader ) )
// 			return false;
// 		return true;
// 	}
=======
		// close the file
		file.close();
		return valid;
	}
	
// 	bit parse( COFFReader reader )
// 	{
// 		if( !parseDOSHeader( reader ) )
// 			return false;
// 		return true;
// 	}
>>>>>>> .r278

    /*
        parse pe module header
    */

<<<<<<< .mine
	bool parse( File file )
	{
		// parse dos header
		if( !parseDOSHeader( file ) )
			return false;
=======
	bit parse( File file )
	{
		// parse dos header
		if( !parseDOSHeader( file ) )
			return false;
>>>>>>> .r278

		// parse COFF header
		if( ( coff = parseCOFFHeader( file ) ) == null )
			return false;

		if( verbose ) writeCOFF( coff );

		// parse PE header
		if( !parsePE32Header( file ) )
			return false;

		// parse sections
		if( !parseSectionHeaders( file ) )
			return false;

		// parse debug (DDL) data
		if( !parseDebugData( file ) )
			return false;


        /* 
            populate imports & exports from file module
        */

		// populate exports
		if( !parseExports( file ) )
			return false;

		// populate imports
// 	    if( !parseImports( file ) )
// 			return false;
// 
        /*
            load codeview debug (DDL) data
        */
        if( debugType == DEBUGTYPE.Codeview )
        {
        }

		return true;
	}

<<<<<<< .mine
// check debug (DDL) data
	bool parseDebugData( File file )
	{
		// check image for debug (DDL) directory
		if( datadir.Debug.RVA == 0 )
		{
            debugType = DEBUGTYPE.None;
			writefln( "Image has no debug (DDL) information\n");
=======
// check debug (DDL) data
	bit parseDebugData( File file )
	{
		// check image for debug (DDL) directory
		if( datadir.Debug.RVA == 0 )
		{
            debugType = DEBUGTYPE.None;
			writefln( "Image has no debug (DDL) information\n");
>>>>>>> .r278
			return true;
		}

		// calculate file offset from data directory RVA
		uint debug_dir = RVA2Offset( datadir.Debug.RVA );
		uint dircnt = datadir.Debug.Size / COFFImageDebugDirectory.sizeof;
//        debug (DDL) writefln( "Found %d debug (DDL) director%s at file position 0x%X\n",dircnt,dircnt==1?"y":"ies",debug_dir);
        
        // can only handle 1 debug (DDL) directory right now
        assert( dircnt == 1, "unable to handle multiple debug (DDL) directories yet" );

        debugData = null;
		// read debug (DDL) directories
		for( uint currentdir = 0; currentdir < dircnt; currentdir++ )
		{
			COFFImageDebugDirectory	dir;
			file.position = debug_dir + (currentdir*COFFImageDebugDirectory.sizeof);
			if( file.readBlock( &dir, COFFImageDebugDirectory.sizeof ) != COFFImageDebugDirectory.sizeof )
			{
				writefln( "ReadDebug(): Failed to read Debug directory with %d left\n",dircnt);
				return false;
			}
            
			if( verbose ) writefln(
				"\n\tDEBUG DIRECTORY #%d\n"
				"\t\tType: %s\n"
				"\t\tCharacteristics: %08X\n"
				"\t\tTimeDateStamp: %s %d\n"
				"\t\tVersion: %s.%s\n"
				"\t\tSize of Data: %d\n"
				"\t\tAddress of Raw Data: %08X\n"
				"\t\tPointer to Raw Data: %08X\n",
				currentdir+1,
				DEBUG_TYPE_NAME(dir.Type),
				dir.Characteristics,
				strip(std.string.toString( ctime( cast(time_t*)&(dir.TimeDateStamp)))), dir.TimeDateStamp,
				dir.MajorVersion, dir.MinorVersion,
				dir.SizeOfData,
				dir.AddressOfRawData,
				dir.PointerToRawData );

            // verify size is nonzero
            assert(dir.SizeOfData && dir.PointerToRawData, "invalid debug (DDL) data" );
            if( dir.SizeOfData == 0 || dir.PointerToRawData == 0 ) 
            {
                writefln("invalid debug (DDL) data");
                return false;
            }

			// move file to debug (DDL) data
			file.position = dir.PointerToRawData;

			// read directory data
            debugType = DEBUGTYPE.Unknown;
			debugData.length = dir.SizeOfData;
			if( file.readBlock( debugData.ptr, debugData.length ) != debugData.length )
			{
				writefln( "failure reading debug (DDL) data" );
                return false;
			}
            
			// reset pointer back to debug (DDL) data and parse
			file.position = dir.PointerToRawData;
            
			// process debug (DDL) data
			switch( dir.Type )
			{
				case IMAGE_DEBUG_TYPE_COFF:
					if( verbose ) writefln( "Debug type: COFF" );
//						writefln( "debug (DDL) info type: \n", DEBUG_TYPE_NAME(dir.Type) );
//						readDebug_COFF(dir.PointerToRawData);
					break;
				
                case IMAGE_DEBUG_TYPE_CODEVIEW:
					if( verbose ) writefln( "Debug type: CodeView" );
                    // set debug (DDL) type
                    debugType = DEBUGTYPE.Codeview;

		            // parse codeview data
		            codeView = new CodeViewData;
		            codeView.verbose = verbose;
		            if( !codeView.parse( this, file) )
                    {
                        writefln( "codeview parsing failed" );
                        return false;
                    }
                    else
		            {
                        int i = 0;
		            // create symbols
            //		symbolManager = new SymbolManager;
            //		symbolManager.parse( codeView );
		            }

					break;

				case IMAGE_DEBUG_TYPE_FPO:
					if( verbose ) writefln( "Debug type: Frame pointer offset" );
//						readDebug_FPO(dir.PointerToRawData);
					break;
				
                case IMAGE_DEBUG_TYPE_MISC:
					if( verbose ) writefln( "Debug type: Misc" );
//						readDebug_Misc(dir.PointerToRawData);
					break;
				
                default:
					writefln( "Don't know how to process %s debug (DDL) information\n", DEBUG_TYPE_NAME(dir.Type));
					break;
			}

			// next debug (DDL) directory
		}

		return true;
	}

// populate import & export information
	const uint IMAGE_SECOND_HEADER_OFFSET	= 0x3C;

<<<<<<< .mine
	// read & verify DOS header
	bool parseDOSHeader(File file)
	{
		ushort	signature;
		ushort	ssv;
		uint	pe_sig;
=======
	// read & verify DOS header
	bit parseDOSHeader(File file)
	{
		ushort	signature;
		ushort	ssv;
		uint	pe_sig;
>>>>>>> .r278

		// read signature
		file.position = 0;
		file.read( signature );

		// verify signature
		if( signature != IMAGE_DOS_SIGNATURE )
		{
			writefln( "module has invalid DOS signature %04X\n",signature);
			return false;
		}

		// read ssv
		file.seekSet( 0x18 );
		file.read( ssv );

		// verify ssv
		if( ssv < 0x40 )
		{
			writefln( "module does not appear to be a Windows file\n");
			return false;
		}

		// read pefile offset
		file.seekSet( IMAGE_SECOND_HEADER_OFFSET );
		file.read( peoffset );
		if( verbose ) writefln( "\tPE header offset = 0x%08X", peoffset );

		// read pe signature
		file.seekSet( peoffset );
		file.read( pe_sig );
		if( verbose ) writefln( "\tPE signature = 0x%X", pe_sig );

		// verify NT signature
		if( pe_sig != IMAGE_NT_SIGNATURE )
		{
			writefln( "invalid PE signature 0x%08X\n",pe_sig);
			return false;
		}

		return true;
	}
//const uint IMAGE_BASE_OFFSET             = 13 * uint.sizeof;

<<<<<<< .mine
	bool parsePE32Header( File file )
	{
        assert( coff !is null );
		PEPlusHeader p;
		uint base;
		uint size_remaining;

		// verify optional header size
		if( p.sizeof > coff.SizeOfOptionalHeader )
=======
	bit parsePE32Header( File file )
	{
        assert( coff !is null );
		PEPlusHeader p;
		uint base;
		uint size_remaining;

		// verify optional header size
		if( p.sizeof > coff.SizeOfOptionalHeader )
>>>>>>> .r278
		{
			writefln( "PE Module COFF SizeOfOptionalHeader is too small\n");
			return false;
		}
		size_remaining = coff.SizeOfOptionalHeader;

		// read PE+ header
		if( file.readBlock( &p, p.sizeof ) != p.sizeof )
		{
			writefln( "failed to read PE32 header\n");
			return false;
		}
		size_remaining -= p.sizeof;

		// check magic value
		if( p.Magic == PECOFF_MAGIC_PE )
		{
			// setup PE32 header
			peplus	= false;
			pe		= new PEHeader;
			memcpy( pe, &p, p.sizeof );

			// read the extra header value
			file.read( pe.BaseOfData );
			size_remaining -= base.sizeof;

			// debug (DDL) print
//				if( verbose ) writeCOFF( cast(PEHeader*) pe );
		}
		else if( p.Magic == PECOFF_MAGIC_PEPLUS )
		{
			// setup PE32+ header
			peplus 	= true;
			pe 		= cast(PEHeader*) new PEPlusHeader;
			memcpy( pe, &p, p.sizeof );
		}
		else
		{
			// invalid magic number
			writefln( "illegal PE32 header magic: %08X\n",p.Magic);
			return false;
		}

		// write header values
		if( verbose )
		{
			if( peplus )
				writeCOFF( cast(PEPlusHeader*) pe );
			else
				writeCOFF( cast(PEHeader*) pe );
		}

		// read the windows specific PE32 header
		if( !peplus )
		{
			// verify size
			if( size_remaining < PEWindowsHeader.sizeof )
			{
				writefln( "COFF SizeOfOptionalHeader is too small for Windows specific header");
				return false;
			}

			winpe = new PEWindowsHeader;
			if( file.readBlock( winpe, PEWindowsHeader.sizeof ) != PEWindowsHeader.sizeof )
			{
				writefln( "failed to read PE32 windows header");
				return false;
			}

			size_remaining -= PEWindowsHeader.sizeof;
		}
		else
		{
			// PE32+
			if( size_remaining < PEPlusWindowsHeader.sizeof )
			{
				writefln( "COFF SizeOfOptionalHeader is too small for Windows specific header");
				return false;
			}

			winpe = cast(PEWindowsHeader*) new PEPlusWindowsHeader;
			if( file.readBlock( winpe, PEPlusWindowsHeader.sizeof ) != PEPlusWindowsHeader.sizeof )
			{
				writefln( "failed to read PE32 windows header");
				return false;
			}
			size_remaining -= PEPlusWindowsHeader.sizeof;
		}

		// debug (DDL) print
		if( verbose ) writeCOFF( winpe );
//
		// read data directory tables
		uint dataSize = winpe.NumberOfRVAAndSizes * PEDataDirectory.sizeof;
		if( size_remaining < dataSize )
		{
			writefln( "COFF SizeOfOptionalHeader is too small for data directories");
			return false;
		}

//			writefln( winpe.NumberOfRVAAndSizes * PEDataDirectory.sizeof );
		datadir = new PEDataDirectories;
		if( file.readBlock( datadir, dataSize ) != dataSize )
		{
			writefln( "failed to read PE32 data directories\n");
			return false;
		}

<<<<<<< .mine
		// debug (DDL) print
		if( verbose ) writeCOFF( datadir );

        imageBase = winpe.ImageBase;
		return true;
	}

	bool parseSectionHeaders( File file )
	{
		uint				inVal;
		char[]				tName;
=======
		// debug (DDL) print
		if( verbose ) writeCOFF( datadir );

        imageBase = winpe.ImageBase;
		return true;
	}

	bit parseSectionHeaders( File file )
	{
		uint				inVal;
		char[]				tName;
>>>>>>> .r278
//			COFFSectionHeader*	s;

		// read section headers
		COFFSectionHeader[]	sectionTable;
		sectionTable.length = coff.NumberOfSections;
		if( file.readBlock( sectionTable.ptr, sectionTable.length * COFFSectionHeader.sizeof ) != sectionTable.length * COFFSectionHeader.sizeof )
			return false;

//			COFFSection sect = parseCOFFSectionHeader( COFFSectionHeader* s, file );
		uint i=0;
		while( i < coff.NumberOfSections )
		{
			COFFSection sect = parseCOFFSectionHeader( &sectionTable[i], file );

			/*
			s = new COFFSectionHeader;
			if( !.ReadFile( fh, s, COFFSectionHeader.sizeof, &inVal, null ) )
			{
				writefln( "ReadSectionHeaders(): failed to read section header %d",i);
				return false;
			}
			*/

            sect.index = i++;
			sections ~= sect;
// 			i++;
		}

		if( verbose ) writeSections();
		/*
//			for( it=section.begin(); it < section.end(); it++)
		foreach( COFFSectionHeader it; sectionTable )
		{
			tName = .toString(cast(char*)it.Name.ptr);
//!				memcpy(tName,&(it.Name),sizeof(it.Name));
			writefln(
				"\tSection info:\n"
				"\t\tName: %s\n"
				"\t\tVirtual Size: 0x%X\n"
				"\t\tVirtual Address: 0x%08X\n"
				"\t\tSize of Raw Data: %d\n"
				"\t\tPointer to Raw Data: 0x%08X\n"
				"\t\tPointer to Relocations: 0x%08X\n"
				"\t\tPointer to Line numbers: 0x%08X\n"
				"\t\tNumber of Relocations: %d\n"
				"\t\tNumber of Line numbers: %d\n"
				"\t\tCharacteristics: %08X\n",
				tName,
				it.VirtualSize,
				it.VirtualAddress,
				it.SizeOfRawData,
				it.PointerToRawData,
				it.PointerToRelocations,
				it.PointerToLineNumbers,
				it.NumberOfRelocations,
				it.NumberOfLineNumbers,
				it.Characteristics);
		}
		*/

		return true;
	}

<<<<<<< .mine
// pe-coff exports
	bool parseExports( File file )
	{
		// skip empty export directories
		if( datadir.Export.RVA == 0 )
		{
			if( verbose ) writefln( "populateExports: Module has no Export entry" );
			return true;
		}
=======
// pe-coff exports
	bit parseExports( File file )
	{
		// skip empty export directories
		if( datadir.Export.RVA == 0 )
		{
			if( verbose ) writefln( "populateExports: Module has no Export entry" );
			return true;
		}
>>>>>>> .r278

		uint export_tab;
		uint remaining_size;
		COFFExportDirectoryTable ex;
		COFFExport* et;

		ushort	otemp;
		uint	ntemp;
		char[]	NameTemp;
		uint	etemp;
		char[]	ForwardTemp;


		// get export table offset from data directory
		export_tab = RVA2Offset(datadir.Export.RVA);
		remaining_size = datadir.Export.Size;

		// read export directory table from file
		file.seekSet( export_tab );
		if( file.readBlock( &ex, COFFExportDirectoryTable.sizeof ) != COFFExportDirectoryTable.sizeof )
		{
			writefln( "populateExports: Could not read 0x%08X", export_tab );
			return false;
		}
		remaining_size -= ex.sizeof;

		// get internal dll name
		fileStrCpy( file, RVA2Offset(ex.NameRVA), internal_name );
		if( verbose ) writefln( "\tDLL NAME: '%s'\n", internal_name );

		// debug (DDL) print
		if( verbose ) writeCOFF( &ex );

		uint ExportAddressTable	= RVA2Offset( ex.AddressOfFunctions );
		uint NamePointerRVA		= RVA2Offset( ex.AddressOfNames );
		uint OrdinalTableRVA	= RVA2Offset( ex.AddressOfOrdinals );
		uint name_ord_cnt 		= ex.NumberOfNames;	// Names and ordinals are __required__ to be the same

		while( name_ord_cnt > 0 )
		{
			// Ordinal and Name pointer tables run in parallel
			file.position = OrdinalTableRVA;
			file.read( otemp );
			OrdinalTableRVA += otemp.sizeof;
			if( verbose ) writef( "\t\t\tOrdinal: %d",otemp);

			file.position = NamePointerRVA;
			file.read( ntemp );
			NamePointerRVA += ntemp.sizeof;
			if( verbose ) writef( " - Name RVA: %08X",ntemp);

			if( ntemp )
			{
				// Now see what's the name to it
				if( !fileStrCpy( file, RVA2Offset(ntemp), NameTemp ) )
				{
					writefln( "\nPopulateExportByFile(): Failed to read at 0x%08X\n",ntemp);
					return false;
				}
				if( verbose ) writef( " - '%s'", NameTemp);
			}
			else
			{
				NameTemp = "";
			}

			// The ordinal (without any fixup) is an index in the Export Address Table
			file.position = ExportAddressTable + (4*otemp);
			file.read( etemp );
			// If the export address is NOT within the export section it's a real export, otherwise it's forwarded
			if( etemp )
			{
				if( (etemp > datadir.Export.RVA) && (etemp < (datadir.Export.RVA + datadir.Export.Size)) )
				{
					if( verbose ) writefln( " - Address is a FORWARDER RVA: %08X", etemp );

					if( !fileStrCpy( file, RVA2Offset(etemp), ForwardTemp ) )
					{
						writefln( "PopulateExportByFile(): Failed to read at 0x%08X\n",etemp);
						return false;
					}

					if( verbose ) writefln( " - ", ForwardTemp );

					// create export object
					et 				= new COFFExport;
					et.Name 		= NameTemp;
					et.Ordinal 		= otemp + ex.OrdinalBias;

					et.Address 		= 0x0;
					et.Forwarded 	= true;
					et.ForwardName	= ForwardTemp;

					exports 		~= et;

				}
				else
				{
					if( verbose ) writefln( " - Address: %08X", etemp);

					// create export object
					et = new COFFExport;
					et.Name = NameTemp;
					et.Ordinal = otemp + ex.OrdinalBias;

					et.Address = etemp;
					et.Forwarded = false;
					et.ForwardName = "";
					exports ~= et;
				}
			}
			else
			{
				if( verbose ) writefln( "Export has address of 0x00 - unused\n");
			}

			name_ord_cnt--;
		}
		return true;
	}

public:
// section management
	PIMAGE_SECTION_HEADER findSection(uint flags)
	{
		foreach( COFFSection sect; sections )
		{
			if( sect.header.Characteristics & flags )
				return cast(PIMAGE_SECTION_HEADER)&sect.header;
		}
		return null;
	}

<<<<<<< .mine
	bool fileStrCpy( File file, uint off, inout char[] s )
	{
		bool		zerofound = false;
=======
	bit fileStrCpy( File file, uint off, inout char[] s )
	{
		bit		zerofound = false;
>>>>>>> .r278

		ulong fpsave = file.position();

		// according to MSDN (http://msdn.microsoft.com/library/en-us/fileio/base/setfilepointer.asp)
		// there is a return value of INVALID_SET_FILE_POINTER but this is not defined in any
		// of the include files; great! Hence the zerofound variable.

		file.position( off );

		char[] rstr;
		char c;
		while( !file.eof() )
		{
			file.read( c );
			if( c == '\0' )
			{
				zerofound = true;
				break;
			}
			rstr ~= c;
		}

		if( zerofound )
			s = rstr;
		else
			s = "";

		file.position(fpsave );

		return zerofound;
	}

	// convert file section offset to loaded virtual address
	uint offset2Address( COFFSection sect, uint offset )
	{
//			off = sect.header.VirtualAddress - sect.header.PointerToRawData;
		return offset;
	}

	// convert loaded virtual address to file offset
	uint RVA2Offset( uint rva )
	{
		uint off;
		COFFSection	sect;

		//for( it = section.begin(); it < section.end(); it++)
		foreach( COFFSection it; sections )
		{
			assert( it !is null );
			if( ( rva >= it.header.VirtualAddress ) &&  ( rva <= (it.header.VirtualAddress + it.header.VirtualSize) ) )
			{
				if( sect is null )
					sect = it;
				break;
			}
		}

		if( sect is null )
		{
			writefln( "RVA2Offset(): RVA %08X is in no section",rva);
			return 0;
		}

//			writefln( "RVA %08X is in section %s (%08X)", rva, .toString(cast(char*)sect.Name), sect.VirtualAddress );
		off = sect.header.VirtualAddress - sect.header.PointerToRawData;

//			writefln( "RVA in file is %08X\n", rva - off );

		return rva - off;
	}
}

private extern (C)
{
	// Functions from the C library.
//	int strcmp(char *, char *);
	char* strcat(char *, char *);
	int memcmp(void *, void *, uint);
	char *strstr(char *, char *);
	char *strchr(char *, char);
	char *strrchr(char *, char);
	char *memchr(char *, char, uint);
	void *memmove(void *, void *, uint);
	char* strerror(int);
}

// parse coff section header
COFFSection parseCOFFSectionHeader( COFFSectionHeader* s, File file )
{
	// create new section data
	COFFSection sect 			= new COFFSection;
	sect.header					= *s;

	// get section name
	if( s.Name[0] == '\\' )
	{
		// name is in string table
		assert( false );	 // finish string table
//		char[] sNum = s.Name[1..8];
//		sNum.length = 1;
//		char[] sNum;
//		sNum.length = 1;
//		memcpy( sNum.ptr, s.Name[1..8].ptr, 1 );
	}
	else
	{
		// pad extra space in case name is exactly 8 characters
		sect.name = strip( copyStringz( s.Name ) );
//		char[] s2 = s.Name;
//		s2.length =  s2.length + 1;
//		s2[s2.length-1] = 0;
//		sect.Name = std.string.toString( cast(char*) s2.ptr );
	}

	// handle grouped selections
	int n = find( sect.name, "$" );
	if(  n != -1 )
		sect.group	= sect.name[0..n];
	else
		sect.group	= sect.name;


	// read section data
	if( ( sect.data.length = s.SizeOfRawData ) != 0 )
	{
	//		memset( sect.data.ptr + s.SizeOfRawData, 0, s.VirtualSize - s.SizeOfRawData );
		file.seekSet( s.PointerToRawData );
		if( file.readBlock( sect.data.ptr, s.SizeOfRawData ) != s.SizeOfRawData )
			return null;
	}

	// pad virtual sections
	if( s.SizeOfRawData < s.VirtualSize )
		sect.data.length = s.VirtualSize;

	// grab relocations
	if( s.PointerToRelocations && s.NumberOfRelocations )
	{
		sect.relocs.length = s.NumberOfRelocations;
		int sz = s.NumberOfRelocations * COFFRelocationRecord.sizeof;
		file.seekSet( s.PointerToRelocations );
		if( file.readBlock( sect.relocs.ptr, sz ) != sz )
			return null;
	}

	// grab line numbers
	if( s.PointerToLineNumbers && s.NumberOfLineNumbers )
	{
		sect.lines.length = s.NumberOfLineNumbers;
		int sz = s.NumberOfLineNumbers * COFFLineRecord.sizeof;
		file.seekSet( s.PointerToLineNumbers );
		if( file.readBlock( sect.lines.ptr, sz ) != sz )
			return null;
	}

	return sect;
}




char[] DEBUG_TYPE_NAME( int a )
{
	switch( a )
	{
		default:
		case 0: return "Unknown debug (DDL) type";
		case 1: return "COFF";
		case 2: return "CodeView";
		case 3: return "FPO";
		case 4: return "Misc";
		case 5: return "Exception";
		case 6: return "FixUp";
		case 7: return "OMAP to Src";
		case 8: return "OMAP from Src";
		case 9: return "Borland";
		case 10: return "Reserved";
	}
	return "Unknown debug (DDL) type";
}


// COFF import function
struct COFFImportFunction
{
	uint	Address;
	char[]	Name;
}

// A class to handle the import mess
class PEcoff_import
{
	public:
		char[]					name;
		COFFImportFunction*[]	functions;	// import functions
		this()
		{
//			name = "";
		}

		~this()
		{
//			uint	i,size;
//			size = functions.length;
//			for (i=0; i<size; i++) {
//				delete( functions.back() );
//				functions.pop_back();
//			}
		}


		uint functionByName(char[] name)
		{
			char[]		n = name;
			foreach( COFFImportFunction* it; functions )
			{
				if( it.Name == n )
					return it.Address;
			}
//			vector <COFFImportFunction *>::iterator	it;
//			for ( it = functions.begin() ; it < functions.end(); it++) {
//				if ( (*it).Name == n )
//					return (*it).Address;
//			}
			return 0;
		}

		char[] functionByAddress(uint addr)
		{
			foreach( COFFImportFunction* it; functions )
			{
				if( it.Address == addr )
					return it.Name;
			}
//			vector <COFFImportFunction *>::iterator	it;
//			for ( it = functions.begin() ; it < functions.end(); it++) {
//				if ( (*it).Address == addr )
//					return (char *)((*it).Name);
//			}
			return null;
		}
}
