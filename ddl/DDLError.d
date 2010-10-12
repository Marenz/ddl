/+
	Copyright (c) 2006 Eric Anderton, Lars Ivar Igesund
        
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
	Authors: Eric Anderton, Lars Ivar Igesund
	License: BSD Derivative (see source for details)
	Copyright: 2006 Eric Anderton, Lars Ivar Igesund
*/
module ddl.DDLError;

/**
	Error subclass for DDL internals.  Used when the application needs to halt, due to something
	un-recoverable.
*/
class DDLError{
	char[] message;
	public this(char[] message){
		this.message = 
			"[Error] You have run into a condition not handled, or possibly incorrectly handled, by DDL.\n" ~
			message ~
			"\nPlease create a ticket (or look for similar ones) at http://trac.dsource.org/projects/ddl/newticket, explain the circumstances and paste this message into it. Also, if possible, please attach a minimal, reproducible testcase.\n - Thank You. -"
		;
	}
	
	public char[] toString(){
		return message;
	}
}