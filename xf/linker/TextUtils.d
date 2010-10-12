module xf.linker.TextUtils;


bool endsWith(char[] text, char[] ending) {
	return text.length >= ending.length && text[$-ending.length..$] == ending;
}
