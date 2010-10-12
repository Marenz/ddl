/+
	Copyright (c) 2005-2007 Eric Anderton
        
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
	Support for loading of OMF Binary data.
	
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton
*/
module ddl.omf.OMFBinary;


private import ddl.FileBuffer;
private import ddl.DDLReader;
private import ddl.DDLException;
private import ddl.Utils;
private import ddl.ExpContainer;

private import ddl.omf.OMFException;
private import ddl.omf.OMFReader;

private import tango.core.tools.Demangler;

// HACK
private import tango.text.convert.Format : sprint = Format;

import tango.stdc.stdio;


protected LString decompressSymName(LString sym) {
	char[2048] buf_;
	char[] buf = buf_;
	char[] res = decompressSymbol(cast(char[])sym, &buf);
	if (res.ptr is sym.ptr) {
		return sym[0..res.length];
	} else {
		return cast(LString)res.dup;
	}
}


/**
	(COMENT subrecord)
	This record describes the imported names for a module.
**/
struct IMPDEF{
	LString internalName;
	LString moduleName;
	LString entryName;
	ushort entryOrdinal;
	
	void parse(OMFReader reader){
		ubyte ordinalFlag;
		
		reader.get(ordinalFlag);
		reader.get(internalName);
		internalName = decompressSymName(internalName);
		reader.get(moduleName);
		moduleName = decompressSymName(moduleName);
							
		if(ordinalFlag == 0){
			ubyte peekbyte;
			reader.peek(peekbyte);
			if(peekbyte == 0){
			 	entryName = internalName;
		 	}
		 	else{
			 	reader.get(entryName);
			 	entryName = decompressSymName(entryName);
		 	}
		 	debug (DDL) debugLog("IMPDEF: using entry name: {0}",cast(char[])entryName);
		}
		else{
			assert(reader.hasMore());
			reader.get(entryOrdinal);
			debug (DDL) debugLog("IMPDEF: no entry name - using ordinal #{0}",entryOrdinal);
		}
 	}
}

void parse(inout IMPDEF[] imps,OMFReader reader){
	IMPDEF imp;
	imp.parse(reader);
	imps ~= imp;
}

/**
	(COMENT subrecord)
	This record marks a set of external names as "weak," and for every weak extern,
	the record associates another external name to use as the default resolution.
**/
struct WKEXT{
	OMFIndex weakIndex;
	OMFIndex resolutionIndex;
			
	void parse(OMFReader reader){
		reader.get(weakIndex);
		reader.get(resolutionIndex);
	}
}

void parse(inout WKEXT[] externs,OMFReader reader){
	while (reader.hasMore()){
		WKEXT ext;
		ext.parse(reader);
		externs ~= ext;
	}
}

/**
	The EXTDEF record contains a list of symbolic external references that is, references
	to symbols defined in other object modules. The linker resolves external references by 
	matching the symbols declared in EXTDEF records with symbols declared in PUBDEF records.
**/
struct EXTDEF{
	LString name;
	OMFIndex typeIndex;
	
	void parse(OMFReader reader){
		reader.get(name);	
		name = decompressSymName(name);
		reader.get(typeIndex);
	}
}

void parse(inout EXTDEF[] externs,inout LString[] externNames,OMFReader reader){
	while(reader.hasMore()){
		EXTDEF extdef;		
		extdef.parse(reader);
		extdef.name = decompressSymName(extdef.name);
		externs ~= extdef;
		externNames ~= extdef.name;
	}
}

/**
	The PUBDEF record contains a list of public names. It makes items defined in this object 
	module available to satisfy external references in other modules with which it is bound 
	or linked. The symbols are also available for export if so indicated in an EXPDEF 
	comment record.
**/
struct PUBDEF{
	OMFIndex groupIndex;
	OMFIndex segmentIndex;
	LString name;
	VWord offset;
	OMFIndex typeIndex;	
	
	public void parse(OMFReader reader){
		reader.get(name);
		name = decompressSymName(name);
		reader.get(offset);
		reader.get(typeIndex); // throw out the type index		
	}
}

void parse(inout PUBDEF[] publics,OMFReader reader){
	OMFIndex groupIndex;
	OMFIndex segmentIndex;
	
	reader.get(groupIndex);
	reader.get(segmentIndex);	
	
	ushort baseFrame = 0;

	if(groupIndex != 0 && segmentIndex == 0){
		//TODO: support this
		throw new FeatureNotSupportedException("Group-Relative addressing is not supported.");
	}
	if(groupIndex == 0 && segmentIndex == 0){
		reader.get(baseFrame);
		baseFrame = baseFrame << 4; // multiply the base frame address by 16
	}	
	
	while(reader.hasMore()){
		PUBDEF pub;		
		pub.parse(reader);
		
		pub.groupIndex = groupIndex;
		pub.segmentIndex = segmentIndex;
		pub.offset = cast(VWord)(pub.offset + baseFrame);
		
		publics ~= pub;
	}
}

/**
	The LINNUM record relates line numbers in source code to addresses in object code.
**/
struct LINNUM{
	OMFIndex groupIndex;
	OMFIndex segmentIndex;
	ushort lineNumber;
	VWord segmentOffset;
	
	void parse(OMFReader reader){
		reader.get(lineNumber);
		reader.get(segmentOffset);
	}
}

void parse(inout LINNUM[] lineNumbers,OMFReader reader){
	OMFIndex groupIndex;
	OMFIndex segmentIndex;
	
	reader.get(groupIndex);
	reader.get(segmentIndex);
	
	while(reader.hasMore()){
		LINNUM lin;		
		lin.parse(reader);
		
		lin.groupIndex = groupIndex;
		lin.segmentIndex = segmentIndex;
		
		lineNumbers ~= lin;	
	}
}

/**
	The SEGDEF record describes a logical segment in an object module. 
	It defines the segment's name, length, and	alignment, and the way the segment can be 
	combined with other logical segments at bind, link, or load time.
	
	Object records that follow a SEGDEF record can refer to it to identify a particular 
	segment. The SEGDEF records are ordered by occurrence, and are referenced by segment 
	indexes (starting from 1) in subsequent records.
**/
struct SEGDEF{
	VWord dataLength;
	OMFIndex nameIndex;
	OMFIndex classNameIndex;
	OMFIndex overlayIndex;
	uint byteAlignment;
	ubyte combination;
	
	// combination constants
	enum: ubyte{
		PRIVATE = 0,
		PUBLIC = 4,
		STACK = 5,
		COMMON = 7
	}
	
	char[] getCombination(){
		switch(combination){
		case 0: 
			return "private";
		case 2: 
		case 4:
			return "public";	
		case 5:
			return "stack";
		case 6:
			return "common";
		case 1: 
		case 3: 
		case 7:
			return "(reserved)";		
		default:
		}
	}
	
	void parse(OMFReader reader){	
		ubyte ACBP;
				
		reader.get(ACBP); // used later
		reader.get(dataLength);
		reader.get(nameIndex); // get name index
		reader.get(classNameIndex); // throw out class name index
		reader.get(overlayIndex); // throw out overlay name index
		
		debug (DDL) debugLog("ACBP: {0:b8}",ACBP);		
		
		// alignment
		switch((ACBP & 0b11100000) >> 5){
		case 0: 
			throw new FeatureNotSupportedException("Absolute segments (alignment=0) are not supported in SEGDEF");
			break;
		case 1: byteAlignment = 1; break;
		case 2: byteAlignment = 2; break;
		case 3: byteAlignment = 16; break;
		case 4: byteAlignment = 256; break;
		case 5: byteAlignment = 4; break;
		case 6: byteAlignment = 4096; break;
		default:
			throw new OMFException("Unknown alignment type for SEGDEF");
		}
		
		combination = (ACBP & 0b00011100) >> 2;
		assert(combination != 1 & combination != 3 && combination != 7);
		
		/*
		debug (DDL) if(ACBP & 2){
			if(reader.type & 0x01){
				debugLog("segment is f'ing huge (4GB) ({0})",cast(uint)dataLength); 
			}			
			else{
				debugLog("segment must be zero length ({1})",cast(uint)dataLength);
			}
		}
		else{
			debugLog("normal length: ({0})",cast(uint)dataLength);
		}*/
		
		assert((ACBP & 2) == 0); // assert normal use
		assert(ACBP & 1); // assert use32
	}
}

void parse(inout SEGDEF[] segments,OMFReader reader){
	SEGDEF seg;
	seg.parse(reader);
	segments ~= seg;
}

/**
	This record causes the program segments identified by SEGDEF records to be collected 
	together (grouped). For OS/2, the segments are combined into a logical segment that 
	is to be addressed through a single selector. For MS-DOS, the segments are combined 
	within the same 64K frame in the run-time memory map.
**/
struct GRPDEF{
	OMFIndex nameIndex;
	OMFIndex[] segments;
	ubyte[] segmentTypes;
}

void parse(inout GRPDEF[] groups,OMFReader reader){
	GRPDEF grp;
		
	reader.get(grp.nameIndex);
		
	while(reader.hasMore()){
		ubyte typeIndex;
		OMFIndex segmentIndex;
		
		reader.get(typeIndex); // throw out the type index
		reader.get(segmentIndex); // get the semgent index
		
		grp.segmentTypes ~= typeIndex;
		grp.segments ~= segmentIndex;		
	}
	groups ~= grp;		
}

/**
	The FIXUPP record contains information that allows the linker to resolve (fix up) 
	and eventually relocate	references between object modules. FIXUPP records describe 
	the LOCATION of each address value to be fixed up, the TARGET address to which the 
	fixup refers, and the FRAME relative to which the address computation is performed.
**/
struct FIXUPP{
	bool isSegmentRelative; // is this a segment relative fixup (true=add address of segment, false=use actual address)
	uint destSegmentIndex;
	uint destOffset;
	uint destNameIndex; // symbol name of referenced COMDAT
	uint targetIndex; // external reference
	bool isExternStyleFixup; // true if this uses an external index as a target, false if it is a segment index
	
	void parse(OMFReader reader){
		//not used
	}
}

alias ExpContainer!(FIXUPP) FIXUPPSet;

/**
	Temporary record used to store FIXUPP TARGET and FRAME information
**/
struct FixupThread{
	uint method;
	ushort index;	
}

/**
	Temporary record usd to store LIDATA, LEDATA and COMDAT address information for
	subsequent use by FIXUPP records
	
	TODO: fashion a "Fixup Source" that optionally references COMDAT symbol by name
	so 
	
**/
struct FixupData{
	uint groupIndex;
	uint segmentIndex;
	uint offset;
	OMFIndex destNameIndex;
	FixupThread[4] frameThreads;
	FixupThread[4] targetThreads;	
}

/**
	FixupSet parse routine.
**/
void parse(inout FIXUPPSet fixups,inout FixupData fixupData, OMFReader reader){
	ubyte type;
	uint threadNumber;
	ubyte method;
	FixupThread* fixupThread;
	ubyte offset;
	ubyte location;
	ubyte fixDataByte;
	ubyte frameMethod;
	ushort frameDatum;	
	ubyte targetMethod;
	ushort targetDatum;
	VWord targetDisplacement;
	uint target;
	OMFIndex tmpIndex;
	FIXUPP fix;
								
	while(reader.hasMore()){
		reader.get(type);
		// thread subrecord
		if((type & 0b10000000) == 0){
			threadNumber = type & 0b00000011;
			method = (type & 0b00011100) >> 2;
			
			// find the frame type
			if(type & 0b01000000){	
				fixupThread = &(fixupData.frameThreads[threadNumber]);				
			}
			else{
				fixupThread = &(fixupData.targetThreads[threadNumber]);
			}
			
			// get the index
			if(method < 4){	
				reader.get(tmpIndex);
				fixupThread.index = cast(ushort)tmpIndex;
			}
			else{
				fixupThread.index = 0;
			}
			// set the method		
			fixupThread.method = method;
		}  			
			// Fixup Subrecord
		else{	
			reader.get(offset);

			//bool isSegmentRelativeFixup = (type & 0b01000000) != 0;
			location = (type & 0b00111100) >> 2;
			uint offset2 = cast(uint)offset | ((type & 0b00000011) << 8); // get the high-order bits from the 'locat'
										
			// get the 'fix data' byte
			reader.get(fixDataByte);
			
			ubyte frame = (fixDataByte & 0b01110000) >> 4;
			
			// don't use the frame thread
			if((fixDataByte & 0b10000000) == 0){
				frameMethod = frame;
				if(frame < 3){
					reader.get(tmpIndex);
					frameDatum = tmpIndex;
				}
				else frameDatum = 0;
			}
			// use frame thread
			else{				
				frameMethod = fixupData.frameThreads[frame].method; // get the method
				frameDatum = fixupData.frameThreads[frame].index; // get the datum
			}
			target = (fixDataByte & 0b00000011);
							
			// don't use the target thread
			if((fixDataByte & 0b00001000) == 0){
				targetMethod = target;
				//if((target | (fixDataByte & 0b00000100)) < 3){
					reader.get(tmpIndex);
					targetDatum = tmpIndex;
				//}
			}
			// use target thread
			else{
				targetMethod = fixupData.targetThreads[target].method | (fixDataByte & 0b00000100);
				targetDatum = fixupData.targetThreads[target].index; 
			}
			
			
			targetDisplacement = 0;
			if((fixDataByte & 0b00000100) == 0){
				reader.get(targetDisplacement);
				debug (DDL) debugLog("targetDisplacement: {0} for {1} ({2})",cast(uint)targetDisplacement,fixupData.destNameIndex,offset);
			}
			
			//NOTE: this chunk of code makes a good deal of assumptions as to how the OMF data is formatted
			//NOTE: generally speaking, it only handles a narrow range of potential fixup types
			//NOTE: assume FLAT group for frame
			fix.isSegmentRelative = (type & 0b01000000) != 0;
			fix.destSegmentIndex = fixupData.segmentIndex;
			fix.destOffset = fixupData.offset + offset2;
			fix.destNameIndex = fixupData.destNameIndex;
			fix.targetIndex = targetDatum;
			//NOTE: assumes that non extern fixups are segment fixups
			fix.isExternStyleFixup = (targetMethod == 2 || targetMethod == 6);
			
			debug (DDL) debugLog("targetMethod: {0}",targetMethod);
						
			fixups ~= fix;
			debug (DDL) debugLog("fixups: {0} {1} bytes",fixups.length,fixups.length * FIXUPP.sizeof);
		}
	}
}


/**
	This record provides contiguous binary data-executable code or program data that is 
	part of a program segment. The data is eventually copied into the program's executable 
	binary image by the linker.  
	
	The data bytes may be subject to relocation or fixing up as determined by the presence 
	of a subsequent FIXUPP record, but otherwise they require no expansion when mapped to 
	memory at run time.
**/
struct LIDATA{
	OMFIndex segmentIndex;
	VWord offset;
	void[] data;
	
	void parse(OMFReader reader){	
		reader.get(segmentIndex);
		reader.get(offset);
		
		// multiple data blocks
		while(reader.hasMore()){	
			data ~= cast(void[])parseIteratedData(reader);
		}
	}
}

void parse(inout LIDATA[] iteratedData,inout FixupData fixupData,OMFReader reader){
	LIDATA data;
	data.parse(reader);
	iteratedData ~= data;
		
	fixupData.groupIndex = 0;
	fixupData.segmentIndex = data.segmentIndex;
	fixupData.offset = data.offset;
	fixupData.destNameIndex = 0;
}

ubyte[] parseIteratedData(OMFReader reader){
	VWord repeatCount;
	ushort blockCount;
	ubyte[] result;
	
	reader.get(repeatCount);
	reader.get(blockCount);
	
	debug (DDL) debugLog("parseblock: repeat {0} block count {1}",cast(uint)repeatCount,blockCount);
	
	//build raw data using a repeated block
	if(blockCount == 0){
		ubyte count;					
		
		reader.get(count);
		reader.get(result,count);
	}
	// recursion
	else{
		for(uint i=0; i<blockCount; i++){
			result ~= parseIteratedData(reader);
		}
	}
	
	// use the repeat count repeat rawData 
	
	// BUG? This code didn't do anything meaningful - h3
	/+ubyte[] tempData;
	for(uint i=0; i<repeatCount; i++){
		tempData ~= result;
	}+/
	
	// use rawData to store the result of the repeat
	return result;
}	
		
/**
	Like the LEDATA record, the LIDATA record contains binary data-executable code or 
	program data. The data in an LIDATA record, however, is specified as a repeating 
	pattern (iterated), rather than by explicit enumeration.
	
	The data in an LIDATA record can be modified by the linker if the LIDATA record is 
	followed by a FIXUPP record, although this is not recommended.
**/
struct LEDATA{
	OMFIndex segmentIndex;
	VWord offset;
	void[] data;
	
	void parse(OMFReader reader){
		reader.get(segmentIndex);
		reader.get(offset);
				
		reader.getAll(data);
		data = data.dup; // ensure a distinct copy of the data
	}
}

void parse(inout LEDATA[] enumeratedData,inout FixupData fixupData,OMFReader reader){
	LEDATA data;
	data.parse(reader);
	enumeratedData ~= data;
			
	fixupData.groupIndex = 0;
	fixupData.segmentIndex = data.segmentIndex;
	fixupData.offset = data.offset;
	fixupData.destNameIndex = 0;
}

/**
	The COMDEF record is an extension to the basic set of 8086 object record types. 
	It declares a list of one or more communal variables (uninitialized static data 
	or data that may match initialized static data in another compilation unit).
	
	The size of such a variable is the maximum size defined in any module naming the 
	variable as communal or public. The placement of communal variables is determined 
	by the data type using established conventions (noted below).
**/
struct COMDEF{
	LString communalName;
	OMFIndex typeIndex;
	ubyte length;
	ubyte dataType;
			
	void parse(OMFReader reader){
		reader.get(communalName);
		communalName = decompressSymName(communalName);
		reader.get(typeIndex); // throw out type index
		reader.get(dataType);
						
		if(dataType < 0x51){
			throw new FeatureNotSupportedException("COMDEF segment number only for {0} is not supported",communalName,dataType);
		}
		else if(dataType == 0x61){
			//uint elements = getCOMDEFValue();
			//uint size = getCOMDEFValue();
			length = parseCOMDEFValue(reader) * parseCOMDEFValue(reader);
		}
		else if(dataType == 0x62){
			//uint bytes = getCOMDEFValue();
			length = parseCOMDEFValue(reader);
		}
		else{
			throw new FeatureNotSupportedException("COMDEF type {0:2X} is not supported for {1}",dataType,communalName);
		}
	}
	
	uint parseCOMDEFValue(OMFReader reader){
		ubyte indicator;
		uint value;
		
		reader.get(indicator);
		if(indicator <= 128){
			value = indicator;
		}
		else if(indicator == 0x81){
			ushort shortValue;
			reader.get(shortValue);
			value = shortValue;
		}
		else if(indicator == 0x84){
			ubyte byteValue;
			ushort shortValue;
			reader.get(byteValue);
			reader.get(shortValue);
			value = (byteValue << 16) | shortValue;
		}
		else if(indicator == 0x88){
			reader.get(value);
		}
		else throw new FeatureNotSupportedException("COMDEF numeric type %0.2X is not supported",indicator);
		
		return value;
	}
}

void parse(inout COMDEF[] commonDefinitions,inout LString[] externNames,OMFReader reader){
	while(reader.hasMore()){
		COMDEF def;
		def.parse(reader);
		commonDefinitions ~= def;
		externNames ~= def.communalName;
	}
}

/**
	This record serves the same purpose as the EXTDEF record described earlier. However,
	the symbol named is referred to through a Logical Name Index field. Such a Logical 
	Name Index field is defined through an LNAMES or LLNAMES record.
**/
struct CEXTDEF{
	OMFIndex nameIndex;
	OMFIndex typeIndex;
	
	void parse(OMFReader reader){
		reader.get(nameIndex);
		reader.get(typeIndex);
	}
}

void parse(inout CEXTDEF[] commonExterns,inout LString[] externNames,LString[] names,OMFReader reader){
	while(reader.hasMore()){
		CEXTDEF def;
		def.parse(reader);
		commonExterns ~= def;
		externNames ~= names[def.nameIndex];
	}
}

/**
	The purpose of the COMDAT record is to combine logical blocks of code and data that 
	may be duplicated across a number of compiled modules.
**/
struct COMDAT{
	bool isContinuation; // do we extend the previous COMDAT?
	OMFIndex nameIndex;
	VWord enumDataOffset; // offset relative to start of referenced public
	OMFIndex typeIndex;
	OMFIndex groupIndex; 
	OMFIndex segmentIndex;
	void[] data;
	
	void parse(OMFReader reader){
		ubyte flags;
		ubyte attributes; //NOTE: this looks like 0x10 for data and 0x00 for code
		ubyte alignment; //NOTE: this is reliably zero which states: use the segment's alignment
		
		reader.get(flags);		
		reader.get(attributes);
		reader.get(alignment);		
		reader.get(enumDataOffset);
		reader.get(typeIndex); // type index is thrown out
		reader.get(groupIndex);
		reader.get(segmentIndex);
		
		// assert explicit mode
		assert((attributes & 0x0F) == 0);
		// assert alignment
		assert(alignment == 0);
		// assert seg index
		assert(segmentIndex != 0);
		
		//TODO: verify what rule this is 
		/*
		if(segIdx == 0){
			ushort dummy;
			reader.get(dummy); // ignored 
		}*/
		
		// get name index		
		reader.get(nameIndex);
		
		isContinuation = cast(bool)(flags & 1);
		
		// get data
		reader.getAll(data);
		data = data.dup; // ensure we have our own copy
	}
}

void parse(inout COMDAT[] commonData,inout FixupData fixupData,OMFReader reader){
	while(reader.hasMore()){
		COMDAT data;
		data.parse(reader);
		commonData ~= data;
		
		fixupData.groupIndex = data.groupIndex;
		fixupData.segmentIndex = data.segmentIndex;
		fixupData.offset = data.enumDataOffset;
		fixupData.destNameIndex = data.nameIndex;
	}
}

/**
	This record will be used to output line numbers for functions specified through COMDAT 
	records. Each LINSYM record is associated with a preceding COMDAT record.
**/
struct LINSYM{
	bool isContinuation; // do we extend the previous COMDAT?
	OMFIndex nameIndex;
	ushort lineNumber;
	VWord baseOffset;
	
	void parse(OMFReader reader){
		reader.get(lineNumber);
		reader.get(baseOffset);
	}
}

void parse(inout LINSYM[] lineNumbers,OMFReader reader){
	ubyte flags;
	OMFIndex nameIndex;
	
	reader.get(flags);
	reader.get(nameIndex);
	
	while(reader.hasMore()){
		LINSYM sym;
		sym.parse(reader);
		
		sym.isContinuation = cast(bool)(flags & 1);	
		sym.nameIndex = nameIndex;
		
		lineNumbers ~= sym;
	}
}

/**
	Abstraction of an OMFRecord.  Provides support for record checksums and determining
	word and byte width.
**/
struct OMFRecord{
	ubyte type;
	ushort length;
	ubyte recordType;
	ubyte[] data;
	ubyte checksum;
	
	void doRecordChecksum(){
		if(checksum == 0) return;
		ubyte sum;
		
		// add up every last byte in the record, including these fields
		sum = length & 0xFF;
		sum += (length >> 8) & 0xFF;
		sum += type;
		sum += checksum;
		
		foreach(ubyte b; data){
			sum += b;
		}
		if(sum != 0){
			throw new ChecksumFailedException("record checksum failed (%d != %d)",sum,0);
		}
		
	}
	
	void parse(DDLReader reader){	
		reader.get(type);
		reader.get(length);
		reader.get(data,length-1);
		reader.get(checksum);
		
		recordType = type & 0x01 ? type ^ 0x01 : type;
		
		debug{} else doRecordChecksum();
	}
	
	OMFReader getOMFReader(){
		// determine use32 and use16 type
		if(type & 0x01){
			return new DWordOMFReader(data,type);
		}
		return new WordOMFReader(data,type);
	}
}

struct OMFBinary{
	// records
	IMPDEF[] impdefs;
	WKEXT[] weakExterns;
	EXTDEF[] externs;
	PUBDEF[] publics;
	LINNUM[] lineNumbers;
	SEGDEF[] segments;
	GRPDEF[] groups;
	FIXUPPSet fixups;
	LIDATA[] iteratedData;
	LEDATA[] enumeratedData;
	COMDEF[] communalDefinitions;
	CEXTDEF[] communalExterns;
	COMDAT[] communalData;
	LINSYM[] comdatLineNumbers;
	
	//data
	LString libraryName;
	LString[] names;
	LString[] externNames;
	
	// comment sub data
	char[][] defaultLibSearch;
	
	static char[][uint] recordNameLookup;
	
	
	void deleteData() {
		delete impdefs;
		delete weakExterns;
		delete externs;
		delete publics;
		delete lineNumbers;
		delete segments;
		delete groups;
		fixups.deleteData();
		delete iteratedData;
		delete enumeratedData;
		delete communalDefinitions;
		delete communalExterns;
		delete communalData;
		delete comdatLineNumbers;
		
		delete names;
		delete externNames;
		
		delete defaultLibSearch;
	}
	
	
	static this(){
		recordNameLookup[0x80] =  "THEADR";
		recordNameLookup[0x82] =  "LHEADR";
		recordNameLookup[0x88] =  "COMENT";
		recordNameLookup[0x8A] =  "MODEND";
		recordNameLookup[0x8C] =  "EXTDEF";
		recordNameLookup[0x90] =  "PUBDEF";
		recordNameLookup[0x94] =  "LINNUM";
		recordNameLookup[0x96] =  "LNAMES";
		recordNameLookup[0x98] =  "SEGDEF";
		recordNameLookup[0x9A] =  "GRPDEF";
		recordNameLookup[0x9C] =  "FIXUPP";
		recordNameLookup[0xA0] =  "LEDATA";
		recordNameLookup[0xA2] =  "LIDATA";
		recordNameLookup[0xB0] =  "COMDEF";
		recordNameLookup[0xB2] =  "BAKPAT";
		recordNameLookup[0xB4] =  "LEXTDEF";
		recordNameLookup[0xB6] =  "LPUBDEF";
		recordNameLookup[0xB8] =  "LCOMDEF";
		recordNameLookup[0xBC] =  "CEXTDEF";
		recordNameLookup[0xC2] =  "COMDAT";
		recordNameLookup[0xC4] =  "LINSYM";
		recordNameLookup[0xC6] =  "ALIAS";
		recordNameLookup[0xC8] =  "NBKPAT";
		recordNameLookup[0xCA] =  "LLNAMES";
		recordNameLookup[0xCC] =  "VERNUM";
		recordNameLookup[0xCE] =  "VENDEXT";		
	}
	
	void parse(DDLReader mainReader){
		FixupData fixupData;
		
		fixups.reserve(200);
		
		/*debug{
			GCStats stats;
			
			std.gc.getStats(stats);			
			debugLog("Poolsize: %d UsedSize: %d Freeblocks: %d FreelistSize: %d Pageblocks: %d",
				stats.poolsize, stats.usedsize, stats.freeblocks, stats.freelistsize, stats.pageblocks);
		}*/
		
		//skew indicies so things line up later
		groups.length = groups.length+1;
		segments.length = segments.length+1;
		names.length = names.length+1;
		externs.length = externs.length+1;
		externNames.length = externNames.length+1;
		
		while(mainReader.hasMore()){
			/*debug{
				std.gc.getStats(stats);			
				debugLog("Poolsize: %d UsedSize: %d Freeblocks: %d FreelistSize: %d Pageblocks: %d",
					stats.poolsize, stats.usedsize, stats.freeblocks, stats.freelistsize, stats.pageblocks);
			}*/
			OMFRecord thisRecord;
		
			thisRecord.parse(mainReader);
						
			scope OMFReader reader = thisRecord.getOMFReader();
			
			debug (DDL) debugLog("record: {0:X} ({1:X}) data: {2} {3} length: {4}",thisRecord.recordType,thisRecord.type,thisRecord.data,recordNameLookup[thisRecord.recordType], thisRecord.length);
			debug (DDL) thisRecord.doRecordChecksum();
					
			switch(thisRecord.recordType){
			case 0x80: //THEADR
				parseTHEADR(reader); 
				break;
			
			case 0x88: //COMENT
				parseCOMENT(reader); 
				break;
			
			case 0x8A: //MODEND
				return; // last record
			
			case 0x8C: //EXTDEF
				.parse(externs,externNames,reader);
				break;
			
			case 0x90: //PUBDEF
				.parse(publics,reader); 
				break;
			
			case 0x94: //LINNUM
				.parse(lineNumbers,reader); 
				break;
			
			case 0x96: //LNAMES
				parseNames(reader); 
				break;
			
			case 0x98: //SEGDEF
				.parse(segments,reader); 
				break;
			
			case 0x9A: //GRPDEF
				.parse(groups,reader); 
				break;
			
			case 0x9C: //FIXUPP
				.parse(fixups,fixupData,reader); 
				break;
			
			case 0xA0: //LEDATA
				.parse(enumeratedData,fixupData,reader); 
				break;
			
			case 0xA2: //LIDATA
				.parse(iteratedData,fixupData,reader); 
				break;
				
			case 0xB0: //COMDEF
				.parse(communalDefinitions,externNames,reader); 
				break;
				
			case 0xBC: //CEXTDEF
				.parse(communalExterns,externNames,names,reader); 
				break;
				
			case 0xC2: //COMDAT
				.parse(communalData,fixupData,reader); 
				break;
				
			case 0xC4: //LINSYM
				.parse(comdatLineNumbers,reader); 
				break;
				
			case 0xCA: //LLNAMES
				parseNames(reader); 
				break;
				
			default: //???
				char[] recordName = recordNameLookup[thisRecord.recordType];
				throw new FeatureNotSupportedException("Unsupported Record: {0}",recordName);
			}
		}		
	}
	
	void parseTHEADR(OMFReader reader){
		/**
			"More than one header record
			is allowed (as a result of an object bind, or if the source arose from multiple files as a result of include
			processing)." - the OMF spec
			
			Since we want just one name and DMD seems to put the module's name as the first THEADR, let's skip
			over all the subsequent ones.
			Perhaps we should get all the names? Not sure, TODO. - h3r3tic, 2008/11/17
		*/
		
		if (libraryName is null) {
			reader.get(libraryName);
		} else {
			char[] otherName;
			reader.get(otherName);
		}
	}
	
	void parseCOMENT(OMFReader reader){
		ubyte commentType;
		ubyte commentClass;
				
		reader.get(commentType);
		reader.get(commentClass);
						
		debug (DDL) debugLog("COMENT class: {0:X}", commentClass);
		
		switch(commentClass){
		case 0x9F: // external library name (dependency)
			void[] data;
			reader.getAll(data);
			defaultLibSearch ~= cast(char[])data;
			break;
			
		case 0xA0: // OMF extensions
			ubyte extensionType;
			reader.get(extensionType);
														
			switch(extensionType){
			case 0x01: // import definition record
				version(Windows){
					.parse(impdefs,reader);		
				}
				else{
					throw new Exception("Non-Windows operating systems cannot support implib style OMF binaries.");
				}
			default:
				debug (DDL) debugLog("unhandled extensionType: {0:X}",extensionType);				
			}
			break;

		case 0xA8: // Weak extern (dependency)
		uint b = reader.hasMore();
			.parse(weakExterns,reader);
			break;	
			
		default:
			debug (DDL) debugLog("unhandled commentClass: {0:X}",commentClass);				
		}
	}
	
	void parseNames(OMFReader reader){
		while(reader.hasMore()){
			LString name;
			reader.get(name);
			name = decompressSymName(name);
			this.names ~= name;
		}
	}
		
	public char[] toString(){
		char[] result = "";
		//ExtSprintClass sprint = new ExtSprintClass(1024);
		
		result ~= "LibraryName: " ~ cast(char[])libraryName ~ "\n";
		
		result ~= "LNAME/LLNAME:\n";
		foreach(idx,name; names){
			if(idx == 0) continue;
			result ~= sprint("  {0}: {1}\n",idx,cast(char[])name);
		}
		
		result ~= "IMPDEF:\n";
		foreach(idx,imp; impdefs){
			with(imp){
				char[] internal = internalName;
				char[] mod = moduleName;
				if(entryName){
					result ~= sprint("  {0}: {1} in {2} as {3}\n",idx,internal,mod,cast(char[])entryName);
				}
				else{
					result ~= sprint("  {0}: {1} in {2} as #{3}\n",idx,internal,mod,entryOrdinal);
				}
			}
		}
		
		result ~= "WKEXT:\n";
		foreach(idx,weak; weakExterns){
			with(weak){
				char[] defaultName = externNames[resolutionIndex];
				char[] weakName = externNames[weakIndex];
				uint externsLength = externs.length;
				uint cextedfsLength = communalExterns.length;	
									
				result ~= sprint("  {0}: ({1}) {2} --> ({3}) {4}\n",idx,cast(uint)weakIndex,weakName,cast(uint)resolutionIndex,defaultName);
			}
		}

		result ~= "EXTERN:\n";
		foreach(idx,ext; externs){
			with(ext){
				char[] name = cast(char[])name;
				result ~= sprint("  {0}: {1}\n",idx,name);
			}
		}	
			
		result ~= "PUBDEF:\n";
		foreach(idx,pub; publics){
			with(pub){
				char[] thisName = name;
				char[] segment = names[segments[segmentIndex].nameIndex];
				char[] group = groupIndex > 0 ? cast(char[])names[groups[groupIndex].nameIndex] : "(none)";
				uint ofs = cast(uint)offset;
				
				result ~= sprint("  {0}: {1} {2}:{3}:{4:8X}\n",idx,thisName,group,segment,ofs);
			}
		}	

		result ~= "SEGDEF:\n";
		foreach(idx,seg; segments){
			if(idx == 0) continue;
			with(seg){
				char[] name = names[nameIndex];
				char[] className = names[classNameIndex];
				char[] overlayName = overlayIndex > 0 ? cast(char[])names[overlayIndex] : "(no overlay)";
				uint length = dataLength;
				char[] combination = getCombination();
								
				result ~= sprint("  {0}: {1} {2} {3} {4} {5} bytes align:{6}\n",idx,name,className,overlayName,combination,length,byteAlignment);
			}
		}	

		result ~= "GRPDEF:\n";
		foreach(idx,grp; groups){
			if(idx == 0) continue;
			with(grp){
				char[] name = names[nameIndex];
				result ~= sprint("  {0}: {1}",idx,name);
				
				foreach(segmentIndex; segments){
					result ~= " " ~ cast(char[])names[this.segments[segmentIndex].nameIndex];
				}
				result ~= "\n";
			}
		}	
		result ~= "FIXUPP:\n";
		foreach(idx,fix; fixups){
			with(fix){
				char[] segment = names[segments[destSegmentIndex].nameIndex];
				char[] rel = isSegmentRelative ? "segment" : "self";
				char[] targetName;
				char[] destName;
				
				if(isExternStyleFixup){
					targetName = "extern: " ~ cast(char[])externNames[targetIndex];
				}
				else{
					targetName = "segment: " ~ cast(char[])names[segments[fix.targetIndex].nameIndex];
				}
				
				if(destNameIndex > 0){
					destName = cast(char[])names[destNameIndex] ~ ":";
				}
				
				result ~= sprint("  {0}: {1}:{2}{3} rel: {4} | {5} {6}\n",idx,segment,destName,destOffset,rel,targetIndex,targetName);
			}
		}	
		
		result ~= "LIDATA:\n";
		foreach(idx,lidata; iteratedData){
			with(lidata){
				char[] segment = names[segments[segmentIndex].nameIndex];
				uint ofs = offset;
				result ~= sprint("  {0}: {1} {2} bytes at offset {3}\n",idx,segment,data.length,ofs);
			}
		}		
	
		result ~= "LEDATA:\n";
		foreach(idx,ledata; enumeratedData){
			with(ledata){
				char[] segment = names[segments[segmentIndex].nameIndex];
				uint ofs = offset;
				result ~= sprint("  {0}: {1} {2} bytes at offset {3}\n",idx,segment,data.length,ofs);
			}
		}			
	
		result ~= "COMDEF:\n";
		foreach(idx,comdef; communalDefinitions){
			with(comdef){
				char[] name = communalName;
				result ~= sprint("  {0}: {1} {2} bytes\n",idx,name,length);
			}
		}		
	
		result ~= "CEXTDEF:\n";
		foreach(idx,cextdef; communalExterns){
			with(cextdef){
				char[] name = names[nameIndex];								
				result ~= sprint("  {0}: {1}\n",idx,name);
			}
		}	
	
		result ~= "COMDAT:\n";
		foreach(idx,comdat; communalData){
			with(comdat){
				char[] cont = isContinuation ? "(Continuation) " : "";
				char[] name = names[nameIndex];
				char[] segment = names[segments[segmentIndex].nameIndex];
				char[] group = groupIndex > 0 ? cast(char[])names[groups[groupIndex].nameIndex] : "(none)";
				uint offset = enumDataOffset;
								
				result ~= sprint("  {0}: {1}{2}:{3}:{4:8X} {5} bytes {6}\n",
					idx,cont,group,segment,offset,data.length,name);
			}
		}
	
		result ~= "LINSYM:\n";
		foreach(idx,linsym; comdatLineNumbers){
			with(linsym){
				char[] cont = isContinuation ? "(Continuation) " : "";
				char[] name = names[nameIndex];
				
				result ~= sprint("  {0}: Line {1} --> {2}{3} {4:8X}\n",
					idx,lineNumber,cont,name,cast(uint)baseOffset);
			}
		}
	
		result ~= "LINNUM:\n";
		foreach(idx,linnum; lineNumbers){
			with(linnum){
				char[] segment = names[segments[segmentIndex].nameIndex];
				char[] group = groupIndex > 0 ? cast(char[])names[groups[groupIndex].nameIndex] : "(none)";
				uint offset = segmentOffset;
								
				result ~= sprint("  {0}: Line {1} --> {2}:{3}:{4:8X}\n",
					idx,lineNumber,group,segment,offset);
			}
		}
					
		return result;
	}	
}