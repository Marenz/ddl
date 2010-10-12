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
	Authors: Eric Anderton
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton
*/
module ddl.DDLException;

private import ddl.Utils;
private import tango.text.convert.Format;

/**
	Error subclass for DDL internals.  Used when the application needs to be warned about something
	that could adversely affect its behavior, but is potentially recoverable.  The error message here
	is practically a clone of the one for DDLError for the sole purpose of informing the user 
	(or developer) should the exception never be caught.
*/
class DDLException : Exception{
	/**
		Explicit constructor, suitable to be used within nested vararg calls.
		
		Params;
			fmt = format string for the exception message
			arguments = type info array
			argptr = start of vararg data
	*/
	public this(char[] fmt,TypeInfo[] arguments,void* argptr){
		//ExtSprintClass sprint = new ExtSprintClass(fmt.length + 1024);
		super(Format(arguments,argptr,fmt));
	}
	
	/**
		Typical constructor, flexible enough to be used in most cases.
		
		The syntax of this constructor signature is identical to that used
		for printf-style formatting.
		
		Params;
			fmt = format string for the exception message
	*/
	public this(char[] fmt,...){
		//ExtSprintClass sprint = new ExtSprintClass(fmt.length + 1024);
		super(Format(_arguments,_argptr,fmt));
	}
	
	/**
		Default constructor.
		
		This calls DDLException.boilerplate() internally to generate the complete 
		exception message.
	*/
	//public this(char[] msg){
	//	super(DDLException.boilerplate(msg));
	//	}
	
	/**
		Boilerplate message generator.  
		
		This is used to emit a boilerplate error message, and is used internally by the 
		default constructor.
	*/
	public static char[] boilerplate(char[] message){
		return(
			"[Exception] You have run into a condition not handled, or possibly incorrectly handled, by DDL.\n" ~
			message ~
			"\nPlease create a ticket (or look for similar ones) at http://www.dsource.org/projects/ddl/newticket, explain the circumstances and paste this message into it. Also, if possible, please attach a minimal, reproducible testcase.\n - Thank You. -"
		);
	}
}