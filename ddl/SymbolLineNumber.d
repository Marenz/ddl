module ddl.SymbolLineNumber;


struct SymbolLineNumber {
	char[]	symbolName;
	size_t	baseOffset;
	uint		lineNumber;		// 0 if invalid
}
