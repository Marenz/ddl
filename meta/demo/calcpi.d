/** Calculate pi at compile time
 *
 * Compile with dmd -c pi.d
 */
module calcpi;

import meta.math;
import meta.conv;

/** real evaluateSeries!(real x, real metafunction!(real y, int n) term)
 *
 * Evaluate a power series at compile time.
 *
 * Given a metafunction of the form
 *  real term!(real y, int n),
 * which gives the nth term of a convergent series at the point y 
 * (where the first term is n==1), and a real number x,
 * this metafunction calculates the infinite sum at the point x 
 * by adding terms until the sum doesn't change any more.
 */
template evaluateSeries(real x, alias term, int n=1, real sumsofar=0.0)
{
  static if (n>1 && sumsofar == sumsofar + term!(x, n+1)) {
     const real evaluateSeries = sumsofar;
  } else {
     const real evaluateSeries = evaluateSeries!(x, term, n+1, sumsofar + term!(x, n));
  }
}

/*** Calculate atan(x) at compile time.
 * 
 * Uses the Maclaurin formula
 *  atan(z) = z - z^3/3 + Z^5/5 - Z^7/7 + ...
 */
template atan(real z)
{
	const real atan = evaluateSeries!(z, atanTerm);
}

template atanTerm(real x, int n)
{
	const real atanTerm =  (n & 1 ? 1 : -1) * pow!(x, 2*n-1)/(2*n-1);
}

/// Machin's formula for pi
/// pi/4 = 4 atan(1/5) - atan(1/239).
pragma(msg, "PI = " ~ fcvt!(4.0 * (4*atan!(1/5.0) - atan!(1/239.0))) );

