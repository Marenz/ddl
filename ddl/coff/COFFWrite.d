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
	utils for writing out PE-COFF data structures

	Authors: J Duncan, Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2005, 2006 J Duncan, Eric Anderton
*/

module ddl.coff.COFFWrite;

private import ddl.Utils;
private import ddl.coff.COFF;
private import ddl.coff.COFFBinary;
private import ddl.coff.COFFObject;			// .obj
private import ddl.coff.COFFLibrary;		// .lib
private import ddl.coff.COFFImage;			// .dll & .exe

private import std.string;
private import std.stdio;
private import std.stream;
private import std.date;
private import std.conv;
private import std.c.time;

// output helpers

// COFF header
void writeCOFF( COFFHeader* coff )
{
    writeCOFF(*coff);
}

void writeCOFF( in COFFHeader coff )
{
	writefln( "\n\tCOFF HEADER: " );
	writefln( "\t\tMachine type: %X",				coff.machine );
	writefln( "\t\tNumber of Sections: %s",			coff.NumberOfSections );
	writefln( "\t\tTimeDateStamp: %s",				strip(std.string.toString( ctime( cast(time_t*)&(coff.TimeStamp)))));
	writefln( "\t\tPointer to Symbol table: %08X",	coff.PointerToSymbolTable );
	writefln( "\t\tNumber of Symbols: %s",			coff.NumberOfSymbols );
	writefln( "\t\tSize of Optional Header: %s",	coff.SizeOfOptionalHeader );
	writefln( "\t\tCharacteristics: 0x%04X",		coff.Characteristics );
	if( coff.Characteristics )
	{
		if( coff.Characteristics & COFF_FLAGS_EXECUTABLE_IMAGE )
			writefln( "\t\t\tExecutable image" );
		if( coff.Characteristics & COFF_FLAGS_RELOCS_STRIPPED )
			writefln( "\t\t\tRelocs stripped" );
		if( coff.Characteristics & COFF_FLAGS_LINE_NUMS_STRIPPED )
			writefln( "\t\t\tLines Stripped" );
		if( coff.Characteristics & COFF_FLAGS_LOCAL_SYMS_STRIPPED )
			writefln( "\t\t\tLocal symbols stripped" );
		if( coff.Characteristics & COFF_FLAGS_AGGRESSIVE_WS_TRIM )
			writefln( "\t\t\tAggressive WS trim" );
		if( coff.Characteristics & COFF_FLAGS_LARGE_ADDRESS_AWARE )
			writefln( "\t\t\tLarge address" );
		if( coff.Characteristics & COFF_FLAGS_BYTES_REVERSED_LO )
			writefln( "\t\t\tBytes reversed low" );
		if( coff.Characteristics & COFF_FLAGS_BYTES_REVERSED_HI )
			writefln( "\t\t\tBytes reversed high" );
		if( coff.Characteristics & COFF_FLAGS_16BIT_MACHINE )
			writefln( "\t\t\t16bit" );
		if( coff.Characteristics & COFF_FLAGS_32BIT_MACHINE )
			writefln( "\t\t\t32bit" );
		if( coff.Characteristics & COFF_FLAGS_DLL )
			writefln( "\t\t\tDLL" );
		if( coff.Characteristics & COFF_FLAGS_DEBUG_STRIPPED )
			writefln( "\t\t\tDebug stripped" );
		if( coff.Characteristics & COFF_FLAGS_REMOVABLE_RUN_FROM_SWAP )
			writefln( "\t\t\tRemovable run from swap" );
		if( coff.Characteristics & COFF_FLAGS_SYSTEM )
			writefln( "\t\t\tSystem" );
		if( coff.Characteristics & COFF_FLAGS_UP_SYSTEM_ONLY )
			writefln( "\t\t\tUp system only" );
	}
}

// PE32+ Header
void writeCOFF( PEPlusHeader* pe )
{
	writefln(
		"\n\tPE32+ Header:\n"
		"\t\tMagic: %04X\n"
		"\t\tLinker Version: %d.%d\n"
		"\t\tSize of Code: %d\n"
		"\t\tSize of Initialized Data: %d\n"
		"\t\tSize of Uninitialized Data: %d\n"
		"\t\tAddress of Entry Point: 0x%08X\n"
		"\t\tBase of Code: 0x%08X",
		pe.Magic,
		pe.LinkerMajor, pe.LinkerMinor,
		pe.SizeOfCode,
		pe.SizeOfInitializedData,
		pe.SizeOfUninitializedData,
		pe.AddressOfEntryPoint,
		pe.BaseOfCode );
}

// PE32 Header
void writeCOFF( PEHeader* pe )
{
	writeCOFF( cast(PEPlusHeader*) pe );
	writefln("\t\tBase of Data: 0x%08X", pe.BaseOfData );
}

// PE32 Windows Header
void writeCOFF( PEWindowsHeader* winpe )
{
	writefln(
		"\n\tWindows Specific Header:\n"
		"\t\tImage Base: 0x%08X\n"
		"\t\tSection Alignment: 0x%X\n"
		"\t\tFile Alignment: 0x%X\n"
		"\t\tOperating System: %d.%d\n"
		"\t\tImage Version: %d.%d\n"
		"\t\tSubsystem Version: %d.%d\n"
		"\t\tReserved: 0x%X\n"
		"\t\tSize of Image: %d\n"
		"\t\tSize of Headers: %d\n"
		"\t\tChecksum: 0x%X\n"
		"\t\tSubsystem: 0x%X\n"
		"\t\tDLL Characteristics: %04X\n"
		"\t\tSize of Stack Reserve: %d\n"
		"\t\tSize of Stack Commit: %d\n"
		"\t\tSize of Heap Reserve: %d\n"
		"\t\tSize of Heap Commit: %d\n"
		"\t\tLoader Flags: %08X\n"
		"\t\tNumber of RVA and Size entries: %d",
		winpe.ImageBase,
		winpe.SectionAlignment,
		winpe.FileAlignment,
		winpe.OperatingSystemMajor, winpe.OperatingSystemMinor,
		winpe.ImageVersionMajor, winpe.ImageVersionMinor,
		winpe.SubsystemMajor, winpe.SubsystemMinor,
		winpe.Reserved,
		winpe.SizeOfImage,
		winpe.SizeOfHeaders,
		winpe.Checksum,
		winpe.Subsystem,
		winpe.DLLCharacteristics,
		winpe.SizeOfStackReserve,
		winpe.SizeOfStackCommit,
		winpe.SizeOfHeapReserve,
		winpe.SizeOfHeapCommit,
		winpe.LoaderFlags,
		winpe.NumberOfRVAAndSizes);
}

// PE32 Data Directories
void writeCOFF( PEDataDirectories* datadir )
{
	writefln(
		"\n\tData directories:\n"
		"\t\tExport: 0x%X, %d\n"
		"\t\tImport: 0x%X, %d\n"
		"\t\tResource: 0x%X, %d\n"
		"\t\tException: 0x%X, %d\n"
		"\t\tCertificate: 0x%X, %d\n"
		"\t\tBase Relocation: 0x%X, %d\n"
		"\t\tDebug: 0x%X, %d\n"
		"\t\tArchitecture: 0x%X, %d\n"
		"\t\tGlobal Ptr: 0x%X, %d\n"
		"\t\tThread Local Storage: 0x%X, %d\n"
		"\t\tLoad Config: 0x%X, %d\n"
		"\t\tBound Import: 0x%X, %d\n"
		"\t\tImport Address: 0x%X, %d\n"
		"\t\tDelay Import: 0x%X, %d\n"
		"\t\tCOM+ Runtime: 0x%X, %d\n"
		"\t\tReserved: 0x%X, %s\n",
		datadir.Export.RVA, datadir.Export.Size,
		datadir.Import.RVA, datadir.Import.Size,
		datadir.Resource.RVA, datadir.Resource.Size,
		datadir.Exception.RVA, datadir.Exception.Size,
		datadir.Certificate.RVA, datadir.Certificate.Size,
		datadir.Base_relocation.RVA, datadir.Base_relocation.Size,
		datadir.Debug.RVA, datadir.Debug.Size,
		datadir.Architecture.RVA, datadir.Architecture.Size,
		datadir.GlobalPtr.RVA, datadir.GlobalPtr.Size,
		datadir.ThreadLocalStorage.RVA, datadir.ThreadLocalStorage.Size,
		datadir.LoadConfig.RVA, datadir.LoadConfig.Size,
		datadir.BoundImport.RVA, datadir.BoundImport.Size,
		datadir.ImportAddress.RVA, datadir.ImportAddress.Size,
		datadir.DelayImport.RVA, datadir.DelayImport.Size,
		datadir.COMplus.RVA, datadir.COMplus.Size,
		datadir.Reserved.RVA, datadir.Reserved.Size );
}

// COFF Export Directory
void writeCOFF( COFFExportDirectoryTable* ex )
{
	writefln(
		"\tExport directory:\n"
		"\t\tCharacteristics: %08X\n"
//				"\t\tTime Stamp: %s"
		"\t\tVersion: %d.%d\n"
		"\t\tName RVA: 0x%08X\n"
		"\t\tOrdinal Bias: %d\n"
		"\t\tNumber of Functions: %d\n"
		"\t\tNumber of Names: %d\n"
		"\t\tAddress of Functions: 0x%08X\n"
		"\t\tAddress of Names: 0x%08X\n"
		"\t\tAddress of Ordinals: 0x%08X\n",
		ex.Characteristics,
//				ctime(cast(time_t*)&(ex.TimeStamp)),
		ex.MajorVersion, ex.MiniorVersion,
		ex.NameRVA,
		ex.OrdinalBias,
		ex.NumberOfFunctions,
		ex.NumberOfNames,
		ex.AddressOfFunctions,
		ex.AddressOfNames,
		ex.AddressOfOrdinals);
}

// generic COFF binary object
void writeCOFF( COFFBinary bin )
{
}

// COFF .lib
void writeCOFF( COFFLibrary lib )
{
}

// COFF .obj
void writeCOFF( COFFObject obj )
{
}

// print out a .dll or .exe module
void writeCOFF( COFFImage image )
{
}

// print out a coff section
void writeCOFF( COFFSection sect, bool bRelocs=false, bool bLines=false )
{
	writef(
		"\n\t\tSECTION #%d\n"
		"\t\t  Name: %s\n"
		"\t\t  Group: %s - %s\n"
		"\t\t  Virtual Size: 0x%X\n"
		"\t\t  Virtual Address: 0x%08X\n"
		"\t\t  Size of Raw Data: %d\n"
		"\t\t  Pointer to Raw Data: 0x%08X\n"
		"\t\t  Characteristics: %08X = ",
		sect.index + 1,
		sect.name,
		sect.group,
		sect.description,
		sect.header.VirtualSize,
		sect.header.VirtualAddress,
		sect.header.SizeOfRawData,
		sect.header.PointerToRawData,
		sect.header.Characteristics);

	// print flags
	if( sect.flags & COFF_SECTION_CNT_CODE )				writef( "Executable code, " );
	if( sect.flags & COFF_SECTION_CNT_INITIALIZED_DATA )	writef( "Initialized Data, " );
	if( sect.flags & COFF_SECTION_CNT_UNINITIALIZED_DATA)	writef( "Uninitialized Data, " );
	if( sect.flags & COFF_SECTION_LNK_INFO )				writef( "Link Info, " );
	if( sect.flags & COFF_SECTION_LNK_REMOVE )				writef( "Link Remove, " );
	if( sect.flags & COFF_SECTION_LNK_COMDAT )				writef( "Link COMDAT, " );
	if( sect.flags & COFF_SECTION_MEM_READ )				writef( "Mem Read, " );
	if( sect.flags & COFF_SECTION_MEM_WRITE )				writef( "Mem Write, " );
	if( sect.flags & COFF_SECTION_MEM_EXECUTE )				writef( "Mem Executable, " );
	if( sect.flags & COFF_SECTION_MEM_SHARED )				writef( "Shared, " );
	if( sect.flags & COFF_SECTION_MEM_NOT_PAGED )			writef( "Not Paged, " );
	if( sect.flags & COFF_SECTION_MEM_NOT_CACHED )			writef( "Not Cached, " );
	if( sect.flags & COFF_SECTION_MEM_DISCARDABLE )			writef( "Discardable, " );
	if( sect.flags & COFF_SECTION_LNK_NRELOC_OVFL )			writef( "Link overflow, " );
	writefln( 1 << (((sect.flags >> 20) & 0x0f)), " byte align" );

	// print relocations
	writefln( "\t\t  Relocations: ", sect.relocs.length );
	if( bRelocs ) foreach( COFFRelocationRecord rec; sect.relocs )
	{
		writef( "\t\t\trelocation 0x%08x 0x%08x ", rec.virtualAddress, rec.symbolTableIndex );
		if( rec.type == COFF_REL_I386_ABSOLUTE )
			writefln( "- ABSOLUTE" );
		else if( rec.type == COFF_REL_I386_DIR32 )
			writefln( "- target's 32-bit virtual address" );
		else if( rec.type == COFF_REL_I386_DIR32NB )
			writefln( "- target's 32-bit relative virtual address" );
		else if( rec.type == COFF_REL_I386_SECTION )
			writefln( "- 16-bit-section index of section containing target" );	//, used to support debugging information" );
		else if( rec.type == COFF_REL_I386_SECREL )
			writefln( "- 32-bit offset of target from beginning of section" );	// This is used to support debugging information as well as static thread local storage" );
		else if( rec.type == COFF_REL_I386_REL32 )
			writefln( "- 32-bit relative displacement to target" );	// This supports the x86 relative branch and call instructions" );
		else
			writefln( "- unknown type: ", rec.type );
	}

	// print line numbers
	writefln( "\t\t  Lines: ", sect.lines.length );
	if( bLines ) foreach( COFFLineRecord line; sect.lines )
	{
		if( line.lineNumber == 0 )
		{
			// symbol table offset
			writefln( "\t\t\tsymbol ", line.symbolTableIndex );
		}
		else
		{
			// line number & address
			writefln( "\t\t\tline %d = 0x%08x ", line.lineNumber, line.virtualAddress );
		}
	}
}


