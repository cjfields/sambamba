/*
    This file is part of Sambamba.
    Copyright (C) 2013-2014    Artem Tarasov <lomereiter@gmail.com>

    Sambamba is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    Sambamba is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*/
module sambamba.utils.common.bed;

import std.stdio;
import std.algorithm;
import std.string;
import std.conv;
import std.array;
import std.range;

struct Interval {
    long beg;
    long end;
}

Interval[] nonOverlappingIntervals(Interval[] list) {
    if (list.length == 0)
        return [];
    sort!"a.beg < b.beg"(list);
    size_t cur_position = 0;

    auto cur = list[0];
    foreach (interval; list[1 .. $]) {
        if (cur.end >= interval.beg) {
            cur.end = max(cur.end, interval.end);
        } else {
            list[cur_position++] = cur;
            cur = interval;
        }
    }
    list[cur_position++] = cur;
    return list[0 .. cur_position];
}

alias Interval[][string] BedIndex;

BedIndex readIntervals(string bed_filename) {
    BedIndex index;

    auto f = File(bed_filename);
    foreach (line; f.byLine()) {
        auto str = cast(string)line;
        auto fields = split(str);
        if (fields.length < 2)
            continue;
        string chr = fields[0].dup;
        Interval interval;
        if (fields.length >= 3) {
            interval.beg = to!long(fields[1]);
            interval.end = to!long(fields[2]);
        } else if (fields.length >= 2) {
            interval.beg = to!long(fields[1]);
            interval.end = interval.beg + 1;
        }

        if (interval.beg < interval.end)
            index[chr] ~= interval;
    }

    foreach (k, ref v; index) {
        v = nonOverlappingIntervals(v);
    }
    return index;
}

bool hasOverlap(const(Interval[]) intervals_, Interval interval) {
    auto intervals = intervals_[];
    auto r = intervals.assumeSorted!"a.beg < b.beg".upperBound(Interval(interval.end - 1, -1));
    intervals = intervals[0 .. $ - r.length];
    auto l = intervals.assumeSorted!"a.end < b.end".lowerBound(Interval(-1, interval.beg + 1));
    return intervals.length != l.length;
}

unittest {
    alias Interval I;
    BedIndex index = [
        "1": nonOverlappingIntervals([I(5, 8), I(7, 10), I(22, 25), I(23, 24), I(14, 17)])
    ];
    assert( index["1"] == [I(5, 10), I(14, 17), I(22, 25)]);
    assert(!index["1"].hasOverlap(I(11, 14)));
    assert( index["1"].hasOverlap(I(13, 15)));
    assert(!index["1"].hasOverlap(I(0, 4)));
    assert(!index["1"].hasOverlap(I(0, 5)));
    assert( index["1"].hasOverlap(I(0, 6)));
    assert( index["1"].hasOverlap(I(9, 10)));
    assert(!index["1"].hasOverlap(I(25, 42)));
    assert( index["1"].hasOverlap(I(22, 23)));
    assert(!index["1"].hasOverlap(I(22, 22)));
    assert(!index["1"].hasOverlap(I(20, 22)));
}
