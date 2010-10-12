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

module ddl.coff.CodeView;

import ddl.coff.COFF;			// coff win32 api defines
import ddl.coff.cv4;			// codeview 4 api
import ddl.coff.COFFImage;		// coff dll/exe image module
import ddl.coff.cursor;			// DataCursor util
import ddl.coff.COFFReader;     // codeview data reader
import ddl.coff.CodeViewParser; // codeview data parser

import ddl.coff.DebugSymbol;	// debug (DDL) symbol management

import ddl.Demangle;			// mangle/demangle identifier names

private import std.stdio;
private import std.string;
private import std.file;
private import std.stream;
private import std.c.windows.windows;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// codeview data parser
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


class CodeViewData
{
	COFFImage				image;
	uint 					imageBase; 			// loaded image base

	uint 					debugOffset;		// file offset of the debug (DDL) data
	bit						verbose;			// verbose output

	SymbolModule[]			modules;			// sstModule list
	SymbolModule[]			sourceModules;		// sstSrcModule -> source module list
	SymbolModule[char[]]	moduleMap;			// sstSrcModule -> map module names to modules
	SymbolModule[char[]]	sourceMap;			// sstSrcModule -> map source files to modules

	char[][] 				libs;				// sstLibraries -> library list

// public symbols list

	Symbol[]				symbols;			// all symbols list

	Symbol[]	 			functionSymbols;	// sstGlobalSym -> global functions list
	Symbol[]	 			dataSymbols;		// sstGlobalSym -> global functions list
	Symbol[]				globalSymbols;		// global symbols list
	Symbol[]				globalPublics;		// global publics

	SymbolTypeDef[ushort] 	types;              // type defs

    
    PIMAGE_SECTION_HEADER 	exeSection;		// executable section


	// store special subsections sections
	CVSubSection[]			m_pCVAlignSym;

    this()
    {
    }

	bit parse( COFFImage image_, File file_ )
    {
        image = image_;

        CodeViewParser parser = new CodeViewParser( this );
        parser.verbose = false;
        if(!parser.parse(image,file_))
        {
            return false;
        }

        modules         = parser.modules;
        sourceModules   = parser.sourceModules;
        moduleMap       = parser.moduleMap;
        sourceMap       = parser.sourceMap;
        libs            = parser.libs;

        functionSymbols = parser.functionSymbols;
        dataSymbols     = parser.dataSymbols;
        symbols         = parser.symbols;
        globalSymbols   = parser.globalSymbols;
        globalPublics   = parser.globalPublics;

        types           = parser.types;

        return true;
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// convert a CodeView type index to a string
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////

char[] CVTypeToString( uint type )
{
//	return format( "[unhandled data type: 0x%04x]", type ).dup;

	// custom types
	if( type >= 0x1000 )
		return format("[custom: 0x%04x]",cast(uint)type);

	switch( type )
	{
	// specials
		case T_NOTYPE: 		return "[no type]";		// Uncharacterized type (no type)
		case T_ABS: 		return "[absolute]";	// Absolute symbol
		case T_SEGMENT: 	return "[segment]";		// Segment type
		case T_CURRENCY:	return "[currency]";		// Basic 8-byte currency value
		case T_NOTTRANS:	return "[untranslated]";	// Untranslated type record from Microsoft symbol format

		case T_VOID:		return "void";

		case T_PVOID: 		// Near pointer to void
		case T_PFVOID:		// Far pointer to void
		case T_PHVOID:		// Huge pointer to void
		case T_32PVOID:		// 32-bit near pointer to void
		case T_32PFVOID:	return "void*";		// 32-bit far pointer to void

		case T_NBASICSTR:	// Near Basic string
		case T_FBASICSTR:	return "string";			// Far Basic string

		case T_BIT:			return "bit";				// Bit
		case T_PASCHAR:		return "pascal CHAR";		// Pascal CHAR


	// 8-bit integer - char
		case T_CHAR:		return "char";
		case T_UCHAR:		return "uchar";

		case T_PFCHAR:		// Far pointer to 8-bit signed
		case T_PHCHAR:		// Huge pointer to 8-bit signed
		case T_32PCHAR:		// 16:32 near pointer to 8-bit signed
		case T_32PFCHAR:	// 16:32 far pointer to 8-bit signed
		case T_PCHAR:		return "char*";

		case T_PFUCHAR:		// Far pointer to 8-bit unsigned
		case T_PHUCHAR:		// Huge pointer to 8-bit unsigned
		case T_32PUCHAR:	// 16:32 near pointer to 8-bit unsigned
		case T_32PFUCHAR:	// 16:32 far pointer to 8-bit unsigned
		case T_PUCHAR:		return "uchar*";

	// 16-bit integer
		case T_SHORT:
		case T_INT2:		return "short";

		case T_USHORT:
		case T_UINT2:		return "ushort";

		case T_PINT2:
		case T_PSHORT:
		case T_32PSHORT:	// 16:32 near pointer to 16-bit signed
							return "short*";

		case T_PUSHORT:
		case T_PUINT2:
		case T_32PUSHORT: 	// 16:32 near pointer to 16-bit unsigned
							return "ushort*";

	// 32-bit integer
		case T_INT4:		return "int";
		case T_UINT4:		return "uint";

		case T_32PINT4:		// 16:32 near pointer to 32-bit signed int
		case T_PINT4:		return "int*";

		case T_32PUINT4:	// 16:32 near pointer to 32-bit unsigned int
		case T_PUINT4:		return "uint*";

	// 64-bit integer
		case T_QUAD:		return "long";
		case T_UQUAD:		return "ulong";

		case T_32PQUAD:		// 16:32 near pointer to 64-bit signed
		case T_PQUAD:		return "long*";

		case T_32PUQUAD:	// 16:32 near pointer to 64-bit unsigned
		case T_PUQUAD:		return "ulong*";

	// 32-bit real
		case T_REAL32:		return "float";
		case T_32PREAL32:	// 16:32 near pointer to 32-bit real
		case T_PREAL32:		return "float*";

	// 64-bit real
		case T_REAL64:		return "double";
//		case T_32PREAL64:	// 16:32 near pointer to 32-bit real
//		case T_PREAL64:		return "double*";

	// 80-bit Real Types
		case T_REAL80: 		return "real";		// 80-bit real
		case T_PREAL80: 	// Near pointer to 80-bit real
		case T_PFREAL80: 	// Far pointer to 80-bit real
		case T_PHREAL80: 	// Huge pointer to 80-bit real
		case T_32PREAL80: 	// 16:32 near pointer to 80-bit real
		case T_32PFREAL80: 	// 16:32 far pointer to 80-bit real
   						//	return "real*";

	// unhandled type
		default:		return format( "[unhandled data type: 0x%04x]", type );
	}

	return "";
}

