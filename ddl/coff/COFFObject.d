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
	Windows PE-COFF Object class (.obj file)

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/
module ddl.coff.COFFObject;

import ddl.ExportSymbol;
import ddl.FileBuffer;
import ddl.Utils;

import ddl.coff.COFFReader;
import ddl.coff.COFFBinary;
import ddl.coff.COFFWrite;
import ddl.coff.COFF;

import std.string;
import std.c.string;

class COFFObject : COFFBinary
{
	COFFHeader  header;
	char[]		linkerDirectives;		// link directives
	uint[uint]	externalSymbolMap;

	public this()
	{
	}
	
	public void load(FileBuffer buffer)
	{
		COFFReader reader = new COFFReader(buffer);
		
		parseCOFFHeader(reader);
	}
	
	// parse a coff object file
	protected void parseCOFFHeader(COFFReader reader)
	{
		// read coff header
		reader.get(header);
        COFFHeader  hrd = header;

        // increment past optional header
        reader.setPosition(reader.getPosition() + header.SizeOfOptionalHeader);
		
        // verbose print header
        if( verbose ) writeCOFF( header );			

		// check machine type
		if( header.machine == 0  )
		{
			// object is an import library
//			if( verbose ) writefln( "\tCOFF object is an import library" );
            throw new Exception("COFF object is an import library");
            //! implement this
//			if( !parseImportObject( file ) )
//				throw new Exception( "COFF Object failed to parse import sections\n");
		}
		else if( header.machine != COFF_MACHINE_I386 )
		{
			// report failure
			throw new Exception( "COFF object is not for IA32 Platform" );
		}

		// parse normal object sections
		parseSections( reader );

		// parse COFF symbols
		//parseCOFFSymbols( reader );

		// process relocations to fixups
		foreach( COFFSection sect; sections )
		{
			foreach( COFFRelocationRecord rel; sect.relocs )
			{
				assert( rel.symbolTableIndex in this.symbols );
				
                // find symbol
				COFFSymbol sym = this.symbols[rel.symbolTableIndex];

//				debug (DDL) writef( "adding fixup: 0x%08x - %s ", rel.virtualAddress, sym.toString );

				// generate fixup
				Fixup fix;
				fix.destOffset			= rel.virtualAddress;
				fix.destSectionIndex	= sect.index;

//			sym.header 		= *rec;
//			sym.index 				= i;
//			sym.type				= rec.type;
//			sym.sectionNumber		= rec.;
//			sym.offset				= rec.value;
//			sym.value				= rec.value;
//			sym.storageClass		= rec.storageClass;
//			sym.numberOfAuxSymbols	= rec.numberOfAuxSymbols;

				// check symbol type
				switch( sym.storageClass )
				{
					case COFF_SYM_CLASS_EXTERNAL:	// The Value field indicates the size if the section number is COFF_SYM_UNDEFINED (0). If the section number is not 0, then the Value field specifies the offset within the section.
						if( sym.sectionNumber == 0 )
						{
							// The Value field indicates the size
							fix.isExternStyleFixup	= true;
							fix.targetIndex			= externalSymbolMap[rel.symbolTableIndex];
//							writef( "- external index: %d - external: %s - ", fix.targetIndex, externs[fix.targetIndex].toString  );
						}
						else
						{
							// Value field specifies the offset within the section.
							fix.isExternStyleFixup	= false;
							fix.targetIndex			= rel.symbolTableIndex;
//							writef( "- segment index: %d - ", fix.targetIndex );
						}
						break;

					case COFF_SYM_CLASS_STATIC:	// The Value field specifies the offset of the symbol within the section. If the Value is 0, then the symbol represents a section name.
						// The Value field specifies the offset of the symbol within the section
//						writef( "- static offset: %d - ", sym.value );
						fix.targetIndex			= sym.index;
						fix.isExternStyleFixup	= false;
						break;
//					case COFF_SYM_CLASS_FUNCTION:
//						break;	// Used by Microsoft tools for symbol records that define the extent of a function: begin function (named .bf), end function (.ef), and lines in function (.lf). For .lf records, Value gives the number of source lines in the function. For .ef records, Value gives the size of function code.
//					case COFF_SYM_CLASS_FILE:
//						break; 	// Used by Microsoft tools, as well as traditional COFF format, for the source-file symbol record. The symbol is followed by auxiliary records that name the file.
					default:
						assert( false );
						throw new Exception( "COFF fixup class not supported" );
						break;
				}

				// check type
				switch( rel.type )
				{
					case IMAGE_REL_I386_DIR32:				// The targets 32-bit virtual address.
						fix.isSegmentRelative	= false; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
//						writefln( "fixup type: target" );
						break;
					case IMAGE_REL_I386_REL32:				// The 32-bit relative displacement to the target. This supports the x86 relative branch and call instructions.
						fix.isSegmentRelative	= true; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
//						writefln( "fixup type: 32-bit relative" );
						break;
//					case IMAGE_REL_I386_DIR32NB:	// The targets 32-bit relative virtual address.
//						writefln( "fixup type: relative target" );
//						break;
//					case IMAGE_REL_I386_SECTION:	// The 16-bit-section index of the section containing the target. This is used to support debugging information.
//						writefln( "fixup type: section index" );
//						break;
//					case IMAGE_REL_I386_SECREL:		// The 32-bit offset of the target from the beginning of its section. This is used to support debugging information as well as static thread local storage.
//						writefln( "fixup type: 32-bit offset" );
//						break;
					default:
						assert( false );
						throw new Exception( format( "invalid relocation type: %d", rel.type ) );
				}
//				rel.virtualAddress;
//				rel.type;

//				fix.destSectionIndex	= 0;
//				fix.destOffset			= 0;
//				fix.targetIndex			= 0; 		// external reference
//				fix.isSegmentRelative	= false; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
//				fix.isExternStyleFixup	= false; 	// true if this uses an external index as a target, false if it is a segment index

				fixups ~= fix;
//	uint	virtualAddress;		// Address of the item to which relocation is applied: this is the offset from the beginning of the section, plus the value of the section's RVA/Offset field (see Section 4, "Section Table."). For example, if the first byte of the section has an address of 0x10, the third byte has an address of 0x12.
//	uint	symbolTableIndex;	// A zero-based index into the symbol table. This symbol gives the address to be used for the relocation. If the specified symbol has section storage class, then the symbol's address is the address with the first section of the same name.
//	ushort	type;				// A value indicating what kind of relocation should be performed. Valid relocation types depend on machine type. See Section 5.2.1, "Type Indicators."
			}
		}

	}
<<<<<<< .mine

	// read section headers & sections
	void parseSections(COFFReader reader)
	{
		// read section header table
		COFFSectionHeader[] sectionHeaders;
		sectionHeaders.length = header.NumberOfSections;
		for( uint i; i < header.NumberOfSections; i++ )
        {
            COFFSectionHeader sectionHeader;
            
            reader.get( sectionHeader );

            sectionHeaders ~= sectionHeader;
        }

		// read and process the sections
		foreach( i, s; sectionHeaders )
		{
			// create new section data
			COFFSection sect 	= new COFFSection;
			sect.index 			= i;
			sect.header 		= s;

			// get section name
			if( s.Name[0] != '\\' )
			{
				// pad extra space in case name is exactly 8 characters
				sect.name = strip( copyStringz( s.Name ) );
			}
			else
			{
				// name is in string table
				assert( false );	
                // implement
//				char[] sNum = s.Name[1..8];
//				sNum.length = 1;
//				char[] sNum;
//				sNum.length = 1;
//				memcpy( sNum.ptr, s.Name[1..8].ptr, 1 );
			}

			// handle grouped selections
			int n = find( sect.name, "$" );
			if(  n != -1 )
				sect.group	= sect.name[0..n];
			else
				sect.group	= sect.name;

			// get group
			Group* g = sect.group in groups;
			if( g )
			{
				// add to group
				g.sections 	~= sect;
			}
			else
			{
				// create group
				Group group;
				group.name 		= sect.group;
				group.sections 	~= sect;
				groups[group.name] = group;
			}

 			// read section data
 			if( ( sect.data.length = sect.header.SizeOfRawData ) != 0 )
            {
                reader.setPosition( sect.header.PointerToRawData );
                reader.get( sect.data );    //, sect.header.SizeOfRawData, 0 );
// 				memcpy( sect.data.ptr, cur.data.ptr + sect.header.PointerToRawData, sect.header.SizeOfRawData );
			}

 			// 0 pad virtual sections
			if( s.SizeOfRawData < s.VirtualSize )
			{
				sect.data.length = s.VirtualSize;
// 				memset( sect.data.ptr + s.SizeOfRawData, 0, s.VirtualSize - s.SizeOfRawData );
			}

			// grab relocations
			if( s.PointerToRelocations && s.NumberOfRelocations )
			{
				sect.relocs.length = s.NumberOfRelocations;
                reader.setPosition( s.PointerToRelocations );
                reader.get( sect.relocs ); // sect.data.ptr, s.NumberOfRelocations * COFFRelocationRecord.sizeof, 0 );
//				memcpy( sect.relocs.ptr, cur.data.ptr + s.PointerToRelocations, s.NumberOfRelocations * COFFRelocationRecord.sizeof );
			}

			// grab line numbers
			if( s.PointerToLineNumbers && s.NumberOfLineNumbers )
			{
				sect.lines.length 	= s.NumberOfLineNumbers;
                reader.setPosition( s.PointerToLineNumbers );
                reader.get( sect.lines ); //.ptr, s.NumberOfLineNumbers * COFFLineRecord.sizeof, 0 );
//				memcpy( sect.lines.ptr, cur.data.ptr + s.PointerToLineNumbers, s.NumberOfLineNumbers * COFFLineRecord.sizeof );
			}

			// parse special sections
			switch( sect.group )
			{
				// executable data
				case ".text":
					sect.description = "executable data";
// 					if( !parseTEXT( sect ) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// debug (DDL) data
				case ".debug":
					sect.description = "debug (DDL) data";
// 					if( !parseDEBUG(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// initialized data
				case ".data":
					sect.description = "initialized data";
// 					if( !parseDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// read-only initialized data
				case ".rdata":
					sect.description = "read-only initialized data";
					break;

				// exception data
				case ".pdata":
				case ".xdata":
					sect.description = "exception data";
					break;

				// uninitialized data
				case ".bss":
					sect.description = "uninitialized data";
// 					if( !parseBSS(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// thread local storage
				case ".tls":
					sect.description = "thread local storage";
					break;

				// resources
				case ".rsrc":
					sect.description = "resources";
					break;

				// import tables
				case ".idata":
					sect.description = "import tables";
// 					if( !parseIDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

			// image only

				// export tables
				case ".edata":
					sect.description = "export tables";
					break;

				// relocation data
				case ".reloc":
					sect.description = "relocation data";
					break;

			// object only

				// linker directives
				case ".drectve":
					sect.description = "linker directives";
// 					if( !parseDRECTVE(sect) )
// 						return false;
					break;


				default:
//					writefln( "unknown COFF section: '" ~ sect.name ~ "'" );
					break;
			}

			// add section to list
			sections ~= sect;

			// increment header
//				s++;

//			writefln( "ReadSectionHeaders(): Section header %d (%d Bytes) loaded",i,inVal);
		}
//		if( verbose ) writefln("");
//		if( verbose ) writeSections();
	}

	//Parse sections

	// .drectve a "directive" section has the IMAGE_SCN_LNK_INFO flag set in the section header and the name .drectve
	// The linker removes a .drectve section after processing the information, so the section does not appear in the image file being linked. Note that a section marked with IMAGE_SCN_LNK_INFO that is not named .drectve is ignored and discarded by the linker.
	bool parseDRECTVE( COFFSection sect )
	{
		// verify flags
		if( (sect.flags & COFF_SECTION_LNK_INFO) == 0 )
		{
			//writefln( "section named .drectve did not have COFF_SECTION_LNK_INFO flags, skipping" );
			return true;
		}

		// grab linker directives
		if( sect.data.length )
		{
			if( (linkerDirectives.length = cast(ubyte) sect.data[0]) != 0 )
				memcpy( linkerDirectives.ptr, &sect.data[1], linkerDirectives.length );
			//writefln( "\t\tlinker directives: %s", linkerDirectives );
		}

		return true;
	}

// 	// .idata section
// 	bool parseIDATA( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .text section
// 	bool parseTEXT( COFFSection sect )
// 	{
// 
// 		return true;
// 	}
// 
// 	// .debug (DDL) section
// 	bool parseDEBUG( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .data section
// 	bool parseDATA( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .bss section
// 	bool parseBSS( COFFSection sect )
// 	{
// 		return true;
// 	}
// 


=======

	// read section headers & sections
	void parseSections(COFFReader reader)
	{
		// read section header table
		COFFSectionHeader[] sectionHeaders;
		sectionHeaders.length = header.NumberOfSections;
		for( uint i; i < header.NumberOfSections; i++ )
        {
            COFFSectionHeader sectionHeader;
            
            reader.get( sectionHeader );

            sectionHeaders ~= sectionHeader;
        }

		// read and process the sections
		foreach( i, s; sectionHeaders )
		{
			// create new section data
			COFFSection sect 	= new COFFSection;
			sect.index 			= i;
			sect.header 		= s;

			// get section name
			if( s.Name[0] != '\\' )
			{
				// pad extra space in case name is exactly 8 characters
				sect.name = strip( copyStringz( s.Name ) );
			}
			else
			{
				// name is in string table
				assert( false );	
                // implement
//				char[] sNum = s.Name[1..8];
//				sNum.length = 1;
//				char[] sNum;
//				sNum.length = 1;
//				memcpy( sNum.ptr, s.Name[1..8].ptr, 1 );
			}

			// handle grouped selections
			int n = find( sect.name, "$" );
			if(  n != -1 )
				sect.group	= sect.name[0..n];
			else
				sect.group	= sect.name;

			// get group
			Group* g = sect.group in groups;
			if( g )
			{
				// add to group
				g.sections 	~= sect;
			}
			else
			{
				// create group
				Group group;
				group.name 		= sect.group;
				group.sections 	~= sect;
				groups[group.name] = group;
			}

 			// read section data
 			if( ( sect.data.length = sect.header.SizeOfRawData ) != 0 )
            {
                reader.setPosition( sect.header.PointerToRawData );
                reader.get( sect.data );    //, sect.header.SizeOfRawData, 0 );
// 				memcpy( sect.data.ptr, cur.data.ptr + sect.header.PointerToRawData, sect.header.SizeOfRawData );
			}

 			// 0 pad virtual sections
			if( s.SizeOfRawData < s.VirtualSize )
			{
				sect.data.length = s.VirtualSize;
// 				memset( sect.data.ptr + s.SizeOfRawData, 0, s.VirtualSize - s.SizeOfRawData );
			}

			// grab relocations
			if( s.PointerToRelocations && s.NumberOfRelocations )
			{
				sect.relocs.length = s.NumberOfRelocations;
                reader.setPosition( s.PointerToRelocations );
                reader.get( sect.relocs ); // sect.data.ptr, s.NumberOfRelocations * COFFRelocationRecord.sizeof, 0 );
//				memcpy( sect.relocs.ptr, cur.data.ptr + s.PointerToRelocations, s.NumberOfRelocations * COFFRelocationRecord.sizeof );
			}

			// grab line numbers
			if( s.PointerToLineNumbers && s.NumberOfLineNumbers )
			{
				sect.lines.length 	= s.NumberOfLineNumbers;
                reader.setPosition( s.PointerToLineNumbers );
                reader.get( sect.lines ); //.ptr, s.NumberOfLineNumbers * COFFLineRecord.sizeof, 0 );
//				memcpy( sect.lines.ptr, cur.data.ptr + s.PointerToLineNumbers, s.NumberOfLineNumbers * COFFLineRecord.sizeof );
			}

			// parse special sections
			switch( sect.group )
			{
				// executable data
				case ".text":
					sect.description = "executable data";
// 					if( !parseTEXT( sect ) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// debug (DDL) data
				case ".debug":
					sect.description = "debug (DDL) data";
// 					if( !parseDEBUG(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// initialized data
				case ".data":
					sect.description = "initialized data";
// 					if( !parseDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// read-only initialized data
				case ".rdata":
					sect.description = "read-only initialized data";
					break;

				// exception data
				case ".pdata":
				case ".xdata":
					sect.description = "exception data";
					break;

				// uninitialized data
				case ".bss":
					sect.description = "uninitialized data";
// 					if( !parseBSS(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// thread local storage
				case ".tls":
					sect.description = "thread local storage";
					break;

				// resources
				case ".rsrc":
					sect.description = "resources";
					break;

				// import tables
				case ".idata":
					sect.description = "import tables";
// 					if( !parseIDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

			// image only

				// export tables
				case ".edata":
					sect.description = "export tables";
					break;

				// relocation data
				case ".reloc":
					sect.description = "relocation data";
					break;

			// object only

				// linker directives
				case ".drectve":
					sect.description = "linker directives";
// 					if( !parseDRECTVE(sect) )
// 						return false;
					break;


				default:
//					writefln( "unknown COFF section: '" ~ sect.name ~ "'" );
					break;
			}

			// add section to list
			sections ~= sect;

			// increment header
//				s++;

//			writefln( "ReadSectionHeaders(): Section header %d (%d Bytes) loaded",i,inVal);
		}
//		if( verbose ) writefln("");
//		if( verbose ) writeSections();
	}

	//Parse sections

	// .drectve a "directive" section has the IMAGE_SCN_LNK_INFO flag set in the section header and the name .drectve
	// The linker removes a .drectve section after processing the information, so the section does not appear in the image file being linked. Note that a section marked with IMAGE_SCN_LNK_INFO that is not named .drectve is ignored and discarded by the linker.
	bit parseDRECTVE( COFFSection sect )
	{
		// verify flags
		if( (sect.flags & COFF_SECTION_LNK_INFO) == 0 )
		{
			//writefln( "section named .drectve did not have COFF_SECTION_LNK_INFO flags, skipping" );
			return true;
		}

		// grab linker directives
		if( sect.data.length )
		{
			if( (linkerDirectives.length = cast(ubyte) sect.data[0]) != 0 )
				memcpy( linkerDirectives.ptr, &sect.data[1], linkerDirectives.length );
			//writefln( "\t\tlinker directives: %s", linkerDirectives );
		}

		return true;
	}

// 	// .idata section
// 	bit parseIDATA( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .text section
// 	bit parseTEXT( COFFSection sect )
// 	{
// 
// 		return true;
// 	}
// 
// 	// .debug (DDL) section
// 	bit parseDEBUG( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .data section
// 	bit parseDATA( COFFSection sect )
// 	{
// 		return true;
// 	}
// 
// 	// .bss section
// 	bit parseBSS( COFFSection sect )
// 	{
// 		return true;
// 	}
// 


>>>>>>> .r278
	protected 
}



/+
REFERENCE IMPLEMENTATION
module ddl.coff.COFFObject;

private import ddl.ExportSymbol;
private import ddl.FileBuffer;
private import ddl.Utils;

private import ddl.coff.COFFBinary;
private import ddl.coff.cursor;

private import std.string;
private import std.path;
private import std.stdio;
private import std.stream;
private import std.date;
private import std.conv;
private import std.c.time;

// coff object class
class COFFObject : COFFBinary
{
	// structs used to store final data
	char[]		linkerDirectives;		// link directives
	uint[uint]	externalSymbolMap;

	this(FileBuffer file)
	{
		super();

		// parse data
		parse(file);

		// resolve internal addresses
		resolveInternals();

		// resolve fixups
		resolveFixups( this.fixups );
	}

	// properties
	bool isResolved()	{ return resolved; }

	public char[] toString()
	{
		return format( "module: %s", name );
		char[] output = format( "module: %s\nfile: %s\n", name, filename );
//		return COFFBinary.toString();
/*
		foreach(uint idx,Segment seg; segments)
		{
			output ~= std.string.format("SEG %d [",idx);
			foreach( ubyte bite; seg.data )
				output ~= std.string.format("%0.2X",bite);
			output ~= "]\n";
		}

		foreach(ExternalSymbol ext; externs){
			output ~= std.string.format("EXT: %s ",ext.name);
			output ~= std.string.format("[%d]:%d = %0.8X",ext.segmentIndex,ext.offset,ext.address);
			if(!ext.isResolved){
				output ~= " unresolved\n";
			}
			else output ~= "\n";
		}

		foreach(PublicSymbol pub; publics){
			output ~= std.string.format("PUB: %s [%d]:%d\n",pub.name,pub.segmentIndex,pub.offset);
		}

		output ~= "--all fixups--\n";
		foreach(Fixup fix; fixups){
			if(fix.isExternStyleFixup){
				output ~= std.string.format("Extern FIXUP: [%d]:%d = %s\n",fix.destSectionIndex,fix.destOffset,this.externs[fix.targetIndex].name);
			}
			else{
				output ~= std.string.format("Segment FIXUP: [%d]:%d = %d\n",fix.destSectionIndex,fix.destOffset,fix.targetIndex);
			}
		}


		output ~= "--unresolved fixups--\n";
		foreach(Fixup fix; unresolvedFixups){
			if(fix.isExternStyleFixup){
				output ~= std.string.format("Extern FIXUP: [%d]:%d = %s\n",fix.destSectionIndex,fix.destOffset,this.externs[fix.targetIndex].name);
			}
			else{
				output ~= std.string.format("Segment FIXUP: [%d]:%d = %d\n",fix.destSectionIndex,fix.destOffset,fix.targetIndex);
			}
		}
*/
		return output;
	}

	// parse a coff object file
	protected void parse(FileBuffer buffer)
	{
		// copy coff header
		coff = new COFFHeader;
		memcpy( coff, cur.ptr, COFFHeader.sizeof );
		cur.position += COFFHeader.sizeof;			// increment past header
		cur.position += coff.SizeOfOptionalHeader;	// increment past optional header
		if( verbose ) writeCOFF( coff );			// verbose print header

		// check machine type
		if( coff.machine == 0  )
		{
			// object is an import library
//			if( verbose ) writefln( "\tCOFF object is an import library" );
			assert( false );	//! implement this
//			if( !parseImportObject( file ) )
				throw new Exception( "COFF Object failed to parse import sections\n");
		}
		else if( coff.machine != COFF_MACHINE_I386 )
		{
			// report failure
			throw new Exception( "COFF object file is not for IA32 Platform" );
		}

		// parse normal object sections
		parseSections( reader );

		// parse COFF symbols
		parseCOFFSymbols( reader );

		// process relocations to fixups
		foreach( COFFSection sect; this.sections )
		{
			foreach( COFFRelocationRecord rel; sect.relocs )
			{
				assert( rel.symbolTableIndex in this.symbols );
				// find symbol
				COFFSymbol sym = this.symbols[rel.symbolTableIndex];

				debug (DDL) writef( "adding fixup: 0x%08x - %s ", rel.virtualAddress, sym.toString );

				// generate fixup
				Fixup fix;
				fix.destOffset			= rel.virtualAddress;
				fix.destSectionIndex	= sect.index;

//			sym.header 		= *rec;
//			sym.index 				= i;
//			sym.type				= rec.type;
//			sym.sectionNumber		= rec.;
//			sym.offset				= rec.value;
//			sym.value				= rec.value;
//			sym.storageClass		= rec.storageClass;
//			sym.numberOfAuxSymbols	= rec.numberOfAuxSymbols;

				// check symbol type
				switch( sym.storageClass )
				{
					case COFF_SYM_CLASS_EXTERNAL:	// The Value field indicates the size if the section number is COFF_SYM_UNDEFINED (0). If the section number is not 0, then the Value field specifies the offset within the section.
						if( sym.sectionNumber == 0 )
						{
							// The Value field indicates the size
							fix.isExternStyleFixup	= true;
							fix.targetIndex			= externalSymbolMap[rel.symbolTableIndex];
							writef( "- external index: %d - external: %s - ", fix.targetIndex, externs[fix.targetIndex].toString  );
						}
						else
						{
							// Value field specifies the offset within the section.
							fix.isExternStyleFixup	= false;
							fix.targetIndex			= rel.symbolTableIndex;
							writef( "- segment index: %d - ", fix.targetIndex );
						}
						break;

					case COFF_SYM_CLASS_STATIC:	// The Value field specifies the offset of the symbol within the section. If the Value is 0, then the symbol represents a section name.
						// The Value field specifies the offset of the symbol within the section
						writef( "- static offset: %d - ", sym.value );
						fix.targetIndex			= sym.index;
						fix.isExternStyleFixup	= false;
						break;
//					case COFF_SYM_CLASS_FUNCTION:
//						break;	// Used by Microsoft tools for symbol records that define the extent of a function: begin function (named .bf), end function (.ef), and lines in function (.lf). For .lf records, Value gives the number of source lines in the function. For .ef records, Value gives the size of function code.
//					case COFF_SYM_CLASS_FILE:
//						break; 	// Used by Microsoft tools, as well as traditional COFF format, for the source-file symbol record. The symbol is followed by auxiliary records that name the file.
					default:
						assert( false );
						throw new Exception( "COFF fixup class not supported" );
						break;
				}

				// check type
				switch( rel.type )
				{
					case IMAGE_REL_I386_DIR32:				// The targets 32-bit virtual address.
						fix.isSegmentRelative	= false; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
						writefln( "fixup type: target" );
						break;
					case IMAGE_REL_I386_REL32:				// The 32-bit relative displacement to the target. This supports the x86 relative branch and call instructions.
						fix.isSegmentRelative	= true; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
						writefln( "fixup type: 32-bit relative" );
						break;
//					case IMAGE_REL_I386_DIR32NB:	// The targets 32-bit relative virtual address.
//						writefln( "fixup type: relative target" );
//						break;
//					case IMAGE_REL_I386_SECTION:	// The 16-bit-section index of the section containing the target. This is used to support debugging information.
//						writefln( "fixup type: section index" );
//						break;
//					case IMAGE_REL_I386_SECREL:		// The 32-bit offset of the target from the beginning of its section. This is used to support debugging information as well as static thread local storage.
//						writefln( "fixup type: 32-bit offset" );
//						break;
					default:
						assert( false );
						throw new Exception( format( "invalid relocation type: %d", rel.type ) );
				}
//				rel.virtualAddress;
//				rel.type;

//				fix.destSectionIndex	= 0;
//				fix.destOffset			= 0;
//				fix.targetIndex			= 0; 		// external reference
//				fix.isSegmentRelative	= false; 	// is this a segment relative fixup (true=add address of segment, false=use actual address)
//				fix.isExternStyleFixup	= false; 	// true if this uses an external index as a target, false if it is a segment index

				fixups ~= fix;
//	uint	virtualAddress;		// Address of the item to which relocation is applied: this is the offset from the beginning of the section, plus the value of the section's RVA/Offset field (see Section 4, "Section Table."). For example, if the first byte of the section has an address of 0x10, the third byte has an address of 0x12.
//	uint	symbolTableIndex;	// A zero-based index into the symbol table. This symbol gives the address to be used for the relocation. If the specified symbol has section storage class, then the symbol's address is the address with the first section of the same name.
//	ushort	type;				// A value indicating what kind of relocation should be performed. Valid relocation types depend on machine type. See Section 5.2.1, "Type Indicators."
			}
		}

	}
/+
	// resolve internal symbols
	protected void resolveInternals()
	{
		// create addresses for all of the public symbols
		debug (DDL) printf("resolve internals\n" );
		foreach(inout PublicSymbol pub; this.publics)
		{
			debug (DDL) printf("resolve: %.*s segindex: %d offset: %d\n",pub.name,pub.section,pub.offset);
			if( pub.section == 0 )
			{
				pub.address = cast(void*)pub.offset; //HACK: treat as absolute address
				debug (DDL) printf("fixed: %.*s == 0\n",pub.name);
			}
			else
			{
				//if(pub.segmentIndex == 0) continue; //HACK: workaround for __nullext being located at 0:0

				//TODO: refactor using .getData(uint ofs) to provide a point for group-based addressing
//				pub.address = this.sections[pub.section].getData(this.segments,pub.offset);
				assert( this.sections[pub.section-1] !is null );
				pub.address = this.sections[pub.section-1].getData(pub.offset);
				assert( pub.address );

				//pub.address = &this.segments[pub.segmentIndex].data[pub.offset];
			}
		}

		// go through all the external records, and resolve them to PublicSymbols and Dependencies
		for( uint extIdx=1; extIdx<this.externs.length; extIdx++ )
		{
			ExternalSymbol* ext = &(this.externs[extIdx]);
			if(!ext.isResolved)
			{
				// find the external in the publics
				if( ext.name in this.publics )
				{
					PublicSymbol* pub = &(this.publics[ext.name]);
					ext.address = pub.address;
				}
				else
				{
					this.dependencies[ext.name] = extIdx;
				}
			}
		}
	}
+/

	public void resolveFixups()
	{
		// perform another fixup pass
		Fixup[] tempFixups = this.unresolvedFixups;
		this.unresolvedFixups.length = 0;
		resolveFixups(tempFixups);
	}

	// process fixups and attempt to resolve all of the resolved symbols
	// - unresolved fixups are added to unresolvedFixups
	protected void resolveFixups(Fixup[] fixupSet)
	{
		writefln("resolve fixups (%d)", fixupSet.length );
		for(uint fixIdx=0; fixIdx<fixupSet.length; fixIdx++)
		{
			Fixup* fix = &(fixupSet[fixIdx]);
			uint fixupValue;
			debug (DDL) writef("fixup %d - ", fixIdx );
			if( fix.isExternStyleFixup )
			{
				// fixup is external
				ExternalSymbol* target = &(this.externs[fix.targetIndex]);
				debug (DDL) writef("extern %d (%s)", fix.targetIndex, target.name );
				// verify symbol target is resolved
				if( !target.isResolved )
				{
					writefln(" - symbol unresolved" );
					// cannot fix this up yet, so save it for later
					unresolvedFixups ~= *fix;
					continue;
				}

				// set address value
				fixupValue = cast(uint)target.address;
				writefln( "fixup: %s @ 0x08%x",target.name, fixupValue );
			}
			else
			{
				// fixup is internal symbol
				COFFSymbol* sym = &(this.symbols[fix.targetIndex]);
				debug (DDL) writef("symbol %d (%s)",fix.targetIndex, sym.name );

				if( !sym.isResolved )
				{
					writefln(" - symbol unresolved" );
					// cannot fix this up yet, so save it for later
					unresolvedFixups ~= *fix;
					continue;
				}

//				Segment* seg = &(this.segments[fix.targetIndex]);
//				fixupValue = cast(uint)(seg.data.ptr);
				fixupValue = cast(uint)sym.address;
				writefln("fixup: %s @ 0x08%x", sym.name, fixupValue);
			}


			// get destination address
			uint* dest = cast(uint*)(this.sections[fix.destSectionIndex].data.ptr + fix.destOffset);
			if( !fix.isSegmentRelative )
			{
				// self relative fixup
				uint value = fixupValue - cast(uint)dest - 4; // relative fixup, offset by width of field
				writefln("[self relative] %d dest %0.8X (at %0.8X) to %0.8X",fix.destSectionIndex,*dest,dest,value^0xffffffff);
				*dest = value;
			}
			else
			{
				writefln("[segment] %d dest %0.8X to %0.8X",fix.destSectionIndex,*dest,fixupValue);
				*dest += fixupValue;
			}
		}
	}

	// read coff symbols header
	void parseCOFFSymbols(COFFReader reader )
	{
		// verify coff header
		assert( coff );
		assert( COFFSymbolRecord.sizeof == 18 );
		assert( COFFAuxSymbolFunction.sizeof == 18 );

		// get symbol table
		if( coff.PointerToSymbolTable && coff.NumberOfSymbols )
		{
			symbolTable.length = coff.NumberOfSymbols;
			memcpy( symbolTable.ptr, cur.data.ptr + coff.PointerToSymbolTable, coff.NumberOfSymbols * COFFSymbolRecord.sizeof );
		}

		// get string table
		stringTable.length = *cast(uint*)(cur.data.ptr + coff.PointerToSymbolTable + coff.NumberOfSymbols * COFFSymbolRecord.sizeof);
		assert( stringTable.length >= 4 );
		memcpy( stringTable.ptr, cur.data.ptr + coff.PointerToSymbolTable + coff.NumberOfSymbols * COFFSymbolRecord.sizeof, stringTable.length );

		// process symbol table
		if( verbose ) writefln("\n\tCOFF SYMBOL TABLE" );
		COFFSymbolRecord* rec = symbolTable.ptr;
		for( uint i = 0; i < symbolTable.length; i++ )
		{
			// setup aux data ptr
			char* aux = (cast(char*)rec) + COFFSymbolRecord.sizeof;

			// create symbol
			COFFSymbol sym;
//			sym.header 		= *rec;
			sym.index 				= i;
			sym.type				= rec.type;
			sym.sectionNumber		= rec.sectionNumber;
			sym.offset				= rec.value;
			sym.value				= rec.value;
			sym.storageClass		= rec.storageClass;
			sym.numberOfAuxSymbols	= rec.numberOfAuxSymbols;

			// grab symbol name
			if( rec.zeros == 0 )
			{
				// name is a stringtable offset
				if( rec.offset )
					sym.name = findString( rec.offset );
			}
			else
			{
				// copy stringz
				sym.name = copyStringz( rec.name );
			}

			// save aux symbols
//				if( ( sym.auxSymbols.length = rec.numberOfAuxSymbols ) != 0 )
//				{
//					memcpy( sym.auxSymbols.ptr, symbolTable.ptr + i * COFFSymbolRecord.sizeof, rec.numberOfAuxSymbols * COFFSymbolRecord.sizeof );
//				}

			// print out symbol
			if( verbose )
			{
				writefln("\n\t\tSYMBOL %d: %S", i, sym.name );
				writefln( "\t\t\ttype: ", 	sym.type );
				writefln( "\t\t\tvalue: ", 	sym.value );
				writefln( "\t\t\tlocation: %d:%d (0x%x)", 	sym.sectionNumber, sym.offset, cast(uint) sym.address );
				writefln( "\t\t\taux syms: %d", sym.numberOfAuxSymbols );
			}

			// resolve address
			if( (sym.sectionNumber > 0) && (sym.sectionNumber <= sections.length) )
			{
				COFFSection sect = this.sections[sym.sectionNumber-1];
				assert( sect.data.ptr );
				assert( sect.data.length > sym.offset );
				sym.address = sect.data.ptr + sym.offset;
				if( verbose ) writefln( "\t\t\tsection: ", sect.name );
			}
			else if( cast(short)sym.sectionNumber == COFF_SYMBOL_UNDEFINED )
			{
				if( verbose ) writefln( "\t\t\tsection: undefined" );
			}
			else if( cast(short)sym.sectionNumber == COFF_SYMBOL_ABSOLUTE )
			{
				if( verbose ) writefln( "\t\t\tabsolute symbol" );
			}
			else if( cast(short)sym.sectionNumber == COFF_SYMBOL_DEBUG )
			{
				if( verbose ) writefln( "\t\t\tdebug (DDL) symbol" );
			}
			else
			{
				if( verbose ) writefln( "\t\t\tsection: invalid (%d)", sym.sectionNumber );
			}

			// print storage class
			if( verbose )
			{
				writef("\t\t\tstorage: ");
				switch( sym.storageClass )
				{
				// microsoft used storage classes:
					case COFF_SYM_CLASS_EXTERNAL:			writefln("External" ); 		break;	// The Value field indicates the size if the section number is COFF_SYM_UNDEFINED (0). If the section number is not 0, then the Value field specifies the offset within the section.
					case COFF_SYM_CLASS_STATIC:				writefln("Static" );		break;	// The Value field specifies the offset of the symbol within the section. If the Value is 0, then the symbol represents a section name.
					case COFF_SYM_CLASS_FUNCTION:			writefln("Function");		break;	// Used by Microsoft tools for symbol records that define the extent of a function: begin function (named .bf), end function (.ef), and lines in function (.lf). For .lf records, Value gives the number of source lines in the function. For .ef records, Value gives the size of function code.
					case COFF_SYM_CLASS_FILE:				writefln("Source file"); 	break; 	// Used by Microsoft tools, as well as traditional COFF format, for the source-file symbol record. The symbol is followed by auxiliary records that name the file.

				// standard COFF storage classes:
					case COFF_SYM_CLASS_END_OF_FUNCTION:	writefln("end of function"); 				break;
					case COFF_SYM_CLASS_NULL:				writefln("No storage class assigned."); 	break;
					case COFF_SYM_CLASS_AUTOMATIC:			writefln("Automatic (stack) variable. "); 	break; 	//
					case COFF_SYM_CLASS_REGISTER:			writefln("Register variable"); 				break; 	//. The Value field specifies register number."); 	break;
					case COFF_SYM_CLASS_EXTERNAL_DEF:		writefln("Symbol is defined externally"); 	break; 	//."); 	break;
					case COFF_SYM_CLASS_LABEL:				writefln("Code label"); 					break; 	//. The Value field specifies the offset of the symbol within the section."); 	break;
					case COFF_SYM_CLASS_UNDEFINED_LABEL:	writefln("undefined ref to a code label "); break; 	//."); 	break;
					case COFF_SYM_CLASS_MEMBER_OF_STRUCT:	writefln("Structure member"); 				break; 	//. The Value field specifies nth member."); 	break;
					case COFF_SYM_CLASS_ARGUMENT:			writefln("parameter of a function"); 		break; 	//. The Value field specifies nth argument."); 	break;
					case COFF_SYM_CLASS_STRUCT_TAG:			writefln("Structure tag-name entry"); 		break; 	//."); 	break;
					case COFF_SYM_CLASS_MEMBER_OF_UNION:	writefln("Union member"); 					break; 	//. The Value field specifies nth member."); 	break;
					case COFF_SYM_CLASS_UNION_TAG:			writefln("Union tag-name entry"); 			break; 	//."); 	break;
					case COFF_SYM_CLASS_TYPE_DEFINITION:	writefln("Typedef entry"); 					break; 	//."); 	break;
					case COFF_SYM_CLASS_UNDEFINED_STATIC:	writefln("Static data declaration"); 		break; 	//."); 	break;
					case COFF_SYM_CLASS_ENUM_TAG:			writefln("Enumerated type tagname entry"); 	break; 	//."); 	break;
					case COFF_SYM_CLASS_MEMBER_OF_ENUM:		writefln("Member of enumeration"); 			break; 	//. Value specifies nth member."); 	break;
					case COFF_SYM_CLASS_REGISTER_PARAM:		writefln("Register parameter."); 			break;
					case COFF_SYM_CLASS_BIT_FIELD:			writefln("Bit-field reference"); 			break; 	//. Value specifies nth bit in the bit field."); 	break;
					case COFF_SYM_CLASS_BLOCK:				writefln("beginning or end of block");		break;	//A .bb (beginning of block) or .eb (end of block) record"); 		break; 	//. Value is the relocatable address of the code location."); 	break;
					case COFF_SYM_CLASS_END_OF_STRUCT:		writefln("End of structure entry"); 		break; 	//."); 	break;
					case COFF_SYM_CLASS_SECTION:			writefln("Definition of a section"); 		break; 	// (Microsoft tools use STATIC storage class instead)."); 	break;
					case COFF_SYM_CLASS_WEAK_EXTERNAL:		writefln("Weak external"); 					break; 	//. "); 	break;
					default:								writefln("unknown - ", sym.storageClass ); 	break;
				}
			}

	// process special symbols
			// function definition
			// 	 type - Microsoft tools set this field to 0x20 (function) or 0x0 (not a function). See Section 5.4.3, "Type Representation," for more information.
			if( sym.isFunction )
			{
				// public function
				if( (sym.storageClass == COFF_SYM_CLASS_EXTERNAL) && (sym.sectionNumber > 0) )
				{
					COFFAuxSymbolFunction func;
					if( rec.numberOfAuxSymbols )
						memcpy( &func, aux, COFFAuxSymbolFunction.sizeof );

					// create public symbol
					assert( (sym.name in publics) is null );
					PublicSymbol pub;
					pub.name			= sym.name;
					pub.section			= sym.sectionNumber;
					pub.offset			= sym.offset;
					pub.address			= sym.address;
					publics[pub.name]	= pub;

					// debug (DDL) print
					if( verbose ) writefln( "\t\t\texternal function: '%s' tag: %d, size: %d, line: %d, next: %d", copyStringz( sym.name ), func.TagIndex, func.TotalSize, func.PointerToLinenumber, func.PointerToNextFunction );
				}
				// external function
				else if( (sym.storageClass == COFF_SYM_CLASS_EXTERNAL) && (sym.sectionNumber == 0) && (sym.offset == 0) )
				{
					// create external symbol
					ExternalSymbol	ext;
					externalSymbolMap[sym.index]	= externs.length;
					ext.name 		= sym.name;
					ext.section		= sym.sectionNumber;
					ext.offset		= sym.offset;
					ext.address		= sym.address;

					if( sym.numberOfAuxSymbols )
					{
						ext.tagIndex	= *cast(uint*)aux;
						ext.style 	 	= *cast(uint*)(aux+uint.sizeof);
						writefln( "\t\t\tweak external: 0x%04x flags: 0x%04x (@ 0x%x)", ext.tagIndex, ext.style, ext.offset );
					}

//					if( ext.style == IMAGE_WEAK_EXTERN_SEARCH_NOLIBRARY )
//					{
//					}
//					else if( ext.style == IMAGE_WEAK_EXTERN_SEARCH_LIBRARY )
//					{
//					}
//					else if( ext.style == IMAGE_WEAK_EXTERN_SEARCH_ALIAS )
//					{
//					}

					externs 		~= ext;

				}
			}
			else // not a function
			{
				// filename - source code
				if( sym.storageClass == COFF_SYM_CLASS_FILE )
				{
					assert( sym.name == ".file" );
					assert( sym.numberOfAuxSymbols );
					char[] sourceFile;
					sourceFile.length = sym.numberOfAuxSymbols * COFFSymbolRecord.sizeof;
					memcpy( sourceFile.ptr, aux, sourceFile.length );

					// debug (DDL) print
					if( verbose ) writefln( "\t\t\tfilename: %s", copyStringz( sourceFile ) );
				}
				// function begin, end, or lines
				else if( sym.storageClass == COFF_SYM_CLASS_FUNCTION )
				{
					// get type
					int nType = -1;
					switch( sym.name )
					{
						case ".bf": nType = COFF_SYMBOL_FUNCTION_BEGIN;		break;
						case ".ef": nType = COFF_SYMBOL_FUNCTION_END;		break;
						case ".lf": nType = COFF_SYMBOL_FUNCTION_LINES;		break;
						default:	assert(false);	writefln( "unknown function symbol: ", sym.name );
							break;
					}
	
					if( (nType == COFF_SYMBOL_FUNCTION_BEGIN) || (nType == COFF_SYMBOL_FUNCTION_END) )
					{
						COFFAuxSymbolBEFunction func;
						assert( sym.numberOfAuxSymbols );
						memcpy( &func, aux, COFFAuxSymbolBEFunction.sizeof );
						if( verbose ) 
						{
							if( nType == COFF_SYMBOL_FUNCTION_BEGIN )
								writefln( "\t\t\tbegin function" );
							else
								writefln( "\t\t\tend function: (%d bytes)", sym.value );
						}
					}
					else if( nType == COFF_SYMBOL_FUNCTION_LINES )
					{
						if( verbose ) writefln( "\t\t\tfunction lines: ", sym.value );
					}
				}
				else
				{
					if( verbose ) writefln( "\t\t\tunknown symbol: ", sym.name );
				}
			}

			// add symbol
			symbols[i] = sym;

			// move record past extended symbols
			i 	+= sym.numberOfAuxSymbols;
			rec += sym.numberOfAuxSymbols + 1;

		}

		// print symbol table
		if( 0 ) debug
		{
			writefln("\tCOFF SYMBOL TABLE: ", symbolTable.length );
			foreach( int nSymbol, COFFSymbolRecord sym; symbolTable )
			{
				char[] symName;// = copyStringz(sym.name);
				// grab symbol name
				if( sym.zeros == 0 )
				{
					// name is index into longnames string table
					int nameIndex = sym.offset;
					symName = "name #: " ~ std.conv.toString(nameIndex);
				}
				else
				{
					symName = copyStringz( sym.name );
				}
				writefln("\t\tSYMBOL %d : %S", nSymbol, symName );
			}
		}

	/*
			char* dataPtr = data.ptr + coff.PointerToSymbolTable;
			symbols.length = 0;
			COFFSymbolRecord rec;
			for( uint i = 0; i < coff.NumberOfSymbols; i++ )
			{
				// insert symbol
//				symbols.length = symbols.length + 1;

				// copy symbol record
				memcpy( &rec, dataPtr, COFFSymbolRecord.sizeof );

				// advance data pointer
				dataPtr += COFFSymbolRecord.sizeof;

				// grab aux symbol records
//				for( uint j = 0; j <
				dataPtr += rec.numberOfAuxSymbols * COFFSymbolRecord.sizeof;
				i += rec.numberOfAuxSymbols;

				// add symbol record
				symbols ~= rec;
			}
		}

		// print debug (DDL) output
		debug
		{
			// debug (DDL) print symbols
			writefln("\tCOFF SYMBOL TABLE: ", symbols.length );
			foreach( int nSymbol, COFFSymbolRecord sym; symbols )
			{
				char[] symName;// = copyStringz(sym.name);

				// grab symbol name
				if( sym.zeros == 0 )
				{
					// name is index into longnames string table
					int nameIndex = sym.offset;
					symName = "name #: " ~ std.conv.toString(nameIndex);

					// verify index
//						assert( nameIndex < longnames.length );
//						if( nameIndex >= longnames.length )
//						{
//							// invalid longname index
//							symName = "bad longname offset: " ~ std.string.toString(nameIndex);
//							return false;
//						}
//						else
//						{
//							// convert longname
//							symName = std.string.toString( cast(char*) longnames.ptr+nameIndex );
//						}
				}
				else
				{
					symName = copyStringz(sym.name);
				}


				writefln("\t\tSYMBOL %d : %S", nSymbol, symName );
				writefln("\t\t\t\tvalue: 0x%08x", sym.value );
				writefln("\t\t\t\tsection: ", sym.sectionNumber );
				writefln("\t\t\t\ttype: ", sym.type );
				writefln("\t\t\t\tstorage class: ", sym.storageClass );
				writefln("\t\t\t\taux symbol number: ", sym.numberOfAuxSymbols );
			}
		}
		*/

//		if( coff.machine == 0  )
//		{
//			return true;
			// object is an import library
//		}

		// verify machine type of object file
//		if( coff.machine != COFF_MACHINE_I386 )
//		{
//			writefln( "readCOFFHeader: File is not for IA32 Platform!\n" );
//			return false;
//		}

		// read optional header
		if( coff.SizeOfOptionalHeader )
		{
//			char[]	optHeader;
//			optHeader.length = coff.SizeOfOptionalHeader;
//			stream.readExact( cast(char*)optHeader.ptr, coff.SizeOfOptionalHeader );
		}
	}


	// read section headers & sections
	void parseSections(COFFReader reader)
	{
		// grab section header table from data
		COFFSectionHeader[] sectionTable;
		sectionHeaders.length = header.NumberOfSections;

		memcpy( sectionTable.ptr, cur.ptr, COFFSectionHeader.sizeof * sectionTable.length );

		cur.position += COFFSectionHeader.sizeof * sectionTable.length;

		// read and process all section headers
		foreach( uint i, COFFSectionHeader s; sectionTable )
		{
			// create new section data
			COFFSection sect 	= new COFFSection;
			sect.index 			= i;
			sect.header 		= s;
//			sect.VirtualSize			= s.VirtualSize;
//			sect.VirtualAddress			= s.VirtualAddress;
//			sect.SizeOfRawData			= s.SizeOfRawData;
//			sect.PointerToRawData		= s.PointerToRawData;
//			sect.Characteristics		= s.Characteristics;

			// get section name
			if( s.Name[0] != '\\' )
			{
				// pad extra space in case name is exactly 8 characters
				sect.name = strip( copyStringz( s.Name ) );
			}
			else
			{
				// name is in string table
				assert( false );	// implement
//				char[] sNum = s.Name[1..8];
//				sNum.length = 1;
//				char[] sNum;
//				sNum.length = 1;
//				memcpy( sNum.ptr, s.Name[1..8].ptr, 1 );
			}

			// handle grouped selections
			int n = find( sect.name, "$" );
			if(  n != -1 )
				sect.group	= sect.name[0..n];
			else
				sect.group	= sect.name;

			// get group
			Group* g = sect.group in groups;
			if( g )
			{
				// add to group
				g.sections 	~= sect;
			}
			else
			{
				// create group
				Group group;
				group.name 		= sect.group;
				group.sections 	~= sect;
				groups[group.name] = group;
			}

			// copy section data
			if( ( sect.data.length = sect.header.SizeOfRawData ) != 0 )
			{
				memcpy( sect.data.ptr, cur.data.ptr + sect.header.PointerToRawData, sect.header.SizeOfRawData );
			}

			// 0 pad virtual sections
			if( s.SizeOfRawData < s.VirtualSize )
			{
				sect.data.length = s.VirtualSize;
				memset( sect.data.ptr + s.SizeOfRawData, 0, s.VirtualSize - s.SizeOfRawData );
			}

			// grab relocations
			if( s.PointerToRelocations && s.NumberOfRelocations )
			{
				sect.relocs.length = s.NumberOfRelocations;
				memcpy( sect.relocs.ptr, cur.data.ptr + s.PointerToRelocations, s.NumberOfRelocations * COFFRelocationRecord.sizeof );
			}

			// grab line numbers
			if( s.PointerToLineNumbers && s.NumberOfLineNumbers )
			{
				sect.lines.length 	= s.NumberOfLineNumbers;
				memcpy( sect.lines.ptr, cur.data.ptr + s.PointerToLineNumbers, s.NumberOfLineNumbers * COFFLineRecord.sizeof );
			}

			// parse special sections
			switch( sect.group )
			{
				// executable data
				case ".text":
					sect.description = "executable data";
// 					if( !parseTEXT( sect ) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// debug (DDL) data
				case ".debug":
					sect.description = "debug (DDL) data";
// 					if( !parseDEBUG(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// initialized data
				case ".data":
					sect.description = "initialized data";
// 					if( !parseDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// read-only initialized data
				case ".rdata":
					sect.description = "read-only initialized data";
					break;

				// exception data
				case ".pdata":
				case ".xdata":
					sect.description = "exception data";
					break;

				// uninitialized data
				case ".bss":
					sect.description = "uninitialized data";
// 					if( !parseBSS(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

				// thread local storage
				case ".tls":
					sect.description = "thread local storage";
					break;

				// resources
				case ".rsrc":
					sect.description = "resources";
					break;

				// import tables
				case ".idata":
					sect.description = "import tables";
// 					if( !parseIDATA(sect) )
// 						throw new Exception( "unable to parse section: " ~ sect.name );
					break;

			// image only

				// export tables
				case ".edata":
					sect.description = "export tables";
					break;

				// relocation data
				case ".reloc":
					sect.description = "relocation data";
					break;

			// object only

				// linker directives
				case ".drectve":
					sect.description = "linker directives";
// 					if( !parseDRECTVE(sect) )
// 						return false;
					break;


				default:
					writefln( "unknown COFF section: '" ~ sect.name ~ "'" );
					break;
			}

			// add section to list
			sections ~= sect;

			// increment header
//				s++;

//			writefln( "ReadSectionHeaders(): Section header %d (%d Bytes) loaded",i,inVal);
		}
		if( verbose ) writefln("");
		if( verbose ) writeSections();
	}

	//Parse sections

	// .drectve a "directive" section has the IMAGE_SCN_LNK_INFO flag set in the section header and the name .drectve
	// The linker removes a .drectve section after processing the information, so the section does not appear in the image file being linked. Note that a section marked with IMAGE_SCN_LNK_INFO that is not named .drectve is ignored and discarded by the linker.
	bool parseDRECTVE( COFFSection sect )
	{
		// verify flags
		if( (sect.flags & COFF_SECTION_LNK_INFO) == 0 )
		{
			writefln( "section named .drectve did not have COFF_SECTION_LNK_INFO flags, skipping" );
			return true;
		}

		// grab linker directives
		if( sect.data.length )
		{
			if( (linkerDirectives.length = cast(ubyte) sect.data[0]) != 0 )
				memcpy( linkerDirectives.ptr, &sect.data[1], linkerDirectives.length );
			writefln( "\t\tlinker directives: %s", linkerDirectives );
		}

		return true;
	}

	// .idata section
	bool parseIDATA( COFFSection sect )
	{
		return true;
	}

	// .text section
	bool parseTEXT( COFFSection sect )
	{

		return true;
	}

	// .debug (DDL) section
	bool parseDEBUG( COFFSection sect )
	{
		return true;
	}

	// .data section
	bool parseDATA( COFFSection sect )
	{
		return true;
	}

	// .bss section
	bool parseBSS( COFFSection sect )
	{
		return true;
	}


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

+/