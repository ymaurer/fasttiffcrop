#ifndef ALTORECT_H_
#define ALTORECT_H_

struct alto_rectangle
{
	long x, y, width, height;
	alto_rectangle() { reset(); }
	alto_rectangle(long newx, long newy, long neww, long newh) : x(newx), y(newy), width(neww), height(newh) {}
	void reset() { x = -1; y = -1; width = -1; height = -1; }
	void convert_to_pixel(int dpi = 300) {
		long newx = x * dpi / 254;
		long newy = y * dpi / 254;
		width = (x + width) * dpi / 254 - newx;
		height = (y + height) * dpi / 254 - newy;
		x = newx;
		y = newy;
	}
	void convert_to_mm10(int dpi = 300) {
		long newx = x * 254 / dpi;
		long newy = y * 254 / dpi;
		width = (x + width) * 254 / dpi - newx;
		height = (y + height) * 254 / dpi - newy;
		x = newx;
		y = newy;
	}
	bool undefined() const
	{
		return x == -1;
	}
};

struct altorect_sort
{
	bool operator()(const alto_rectangle &lhs, const alto_rectangle &rhs) const
	// Sort by y, then by x, then by width, then by height
	{
		if (lhs.y < rhs.y) {
			return true;
		} else if (lhs.y == rhs.y) {
			if (lhs.x < rhs.x) {
				return true;
			} else if (lhs.x == rhs.x) {
				if (lhs.width < rhs.width) {
					return true;
				} else if (lhs.width == rhs.width) {
					if (lhs.height < rhs.height) {
						return true;
					} else {
						return false;
					}
				}
			}
		}
		return false;
	}
};

#endif // ALTORECT_H_
