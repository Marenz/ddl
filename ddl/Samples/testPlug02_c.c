/*
 * gcc -c testPlug02_c.c
 */

extern int i;

int blurp() {
	i += 666;
	return i*2;
}
