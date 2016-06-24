/******************************************************************************

    Provides helpers to work with index intervals. Implementation is very
    specialized for inclusion/exclusion of token intervals during recursive
    AST iteration.

    Copyright: Copyright (c) 2016 Sociomantic Labs. All rights reserved

    License: Boost Software License Version 1.0 (see LICENSE for details)

******************************************************************************/

module util.intervals;

@safe:

/**
    Represents sequence of tokens between two indexes in external token array.

    Interval can consist from a single token. Empty intervals are not allowed.
 **/
struct Interval
{
    private
    {
        ptrdiff_t start_;
        ptrdiff_t end_;
    }

    /// index of first token included into the interval
    auto start ( )
    {
        return this.start_;
    }

    /// index of last token included into the interval, will
    /// be the same as `start` if it is interval of length 1
    auto end ( )
    {
        return this.end_;
    }

    /**
        Constructor which simplifies creation of single index intervals
        and ensures index values are sane.
     **/
    this ( ptrdiff_t start, ptrdiff_t end = -1)
    in
    {
        assert (start >= 0);
        assert (start <= end || end < 0);
    }
    body
    {
        import std.exception : enforce;
        enforce (start >= 0);
        this.start_ = start;
        this.end_ = end >= 0 ? end : start;
    }
}

/**
    Collection of individual intervals.

    All its elements contain indexes to same external token array, are
    guaranteed to be ordered and not interleaved.
 **/
struct OrderedIntervals
{
    import std.exception : enforce, assertThrown;

    private Interval[] intervals;

    /**
        Attempts to add a new interval.

        Params:
            start = inclusive start index of interval to add
            end = inclusive end index of interval to add
     **/
    void add ( ptrdiff_t start, ptrdiff_t end = -1)
    {
        static void mustNotInterleave (Interval added, Interval adjacent)
        {
            enforce (
                   added.start > adjacent.end
                || added.end   < adjacent.start
            );
        }

        static bool mergeSubset (Interval added, ref Interval old)
        {
            if (added.isSubsetOf(old))
                // new one is a subset of the old one
                return true;
            if (old.isSubsetOf(added))
            {
                // old one is a subset of the new one
                old = added;
                return true;
            }

            // else independent
            return false;
        }

        // Normalize the input

        auto added = Interval(start, end);

        // Find the first interval that should start after the added one

        import std.algorithm.searching;
        auto index = this.intervals.countUntil!(
            (a, b) => a.start > b.end
        )(added);

        // Check interval before

        auto before = index == -1 ? this.intervals.length - 1 : index - 1;

        if (before != -1)
        {
            if (mergeSubset(added, this.intervals[before]))
                return;

            mustNotInterleave(added, this.intervals[before]);
        }

        // Check interval after

        auto after = index == -1 ? this.intervals.length : index;

        if (after != this.intervals.length)
            mustNotInterleave(added, this.intervals[after]);

        // Totally independent interval

        this.intervals = this.intervals[0 .. after] ~ added
            ~ this.intervals[after .. $];
    }

    unittest
    {
        OrderedIntervals intervals;

        intervals.add(10);
        assert (intervals.intervals == [ Interval(10, 10) ]);

        intervals.add(15, 20);
        assert (intervals.intervals == [ Interval(10, 10), Interval(15, 20) ]);

        intervals.add(15, 18);
        assert (intervals.intervals == [ Interval(10, 10), Interval(15, 20) ]);

        intervals.add(10, 12);
        assert (intervals.intervals == [ Interval(10, 12), Interval(15, 20) ]);

        assertThrown(intervals.add(13, 16));

        intervals.add(13, 14);
        assert (intervals.intervals == [ Interval(10, 12), Interval(13, 14),
            Interval(15, 20) ]);
    }

    /**
        Attempts to remove an interval.

        If removed interval is in the middle of existing interval, the old
        one will be replaced with two smaller intervals - one before and one after.

        Params:
            start = inclusive start index of interval to remove
            end   = inclusive end index of index to remove
     **/
    void remove ( ptrdiff_t start, ptrdiff_t end = -1 )
    {
        auto removed = Interval(start, end);

        // It only makes sense to remove an interval which is a subset
        // of existing interval

        import std.algorithm.searching;
        auto index = this.intervals.countUntil!(
            (a, b) => (a.start <= b.start) && (a.end >= b.end)
        )(removed);

        if (index >= 0)
        {
            Interval[] split_insertion;

            if (this.intervals[index].start != removed.start)
                split_insertion ~= Interval(this.intervals[index].start, removed.start - 1);
            if (this.intervals[index].end != removed.end)
                split_insertion ~= Interval(removed.end + 1, this.intervals[index].end);

            this.intervals = this.intervals[0 .. index]
                ~ split_insertion
                ~ this.intervals[index + 1 .. $];
        }

        // Ignore all other removal calls
    }

    unittest
    {
        OrderedIntervals intervals;

        intervals.intervals = [
            Interval(10, 20),
            Interval(30, 40),
            Interval(42, 42)
        ];

        intervals.remove(12, 12);
        intervals.remove(14, 16);
        intervals.remove(35, 40);
        intervals.remove(42);

        assert (
            intervals.intervals == [
                Interval(10, 11),
                Interval(13, 13),
                Interval(17, 20),
                Interval(30, 34)
            ]
        );
    }

    /**
        Checks for inclusion of specified interval

        Params:
            start = inclusive start index of interval to check
            end = inclusive end index of interval to check

        Returns:
            'true' if specified interval is a subset of one of stored intervals
     **/
    bool contain ( ptrdiff_t start, ptrdiff_t end = -1 )
    {
        import std.algorithm.searching;
        auto interval = Interval(start, end);
        return this.intervals.any!(x => interval.isSubsetOf(x));
    }

    unittest
    {
        OrderedIntervals intervals;

        intervals.intervals = [
            Interval(10, 20),
            Interval(30, 40),
        ];

        assert ( intervals.contain(15));
        assert ( intervals.contain(30, 35));
        assert (!intervals.contain(15, 25));
        assert (!intervals.contain(25, 28));
    }

    /**
        Drops all stored intervals which have end values smaller
        than or equal to specified index

        Params:
            bounding_index = index to check against
     **/
    void removeUntil ( ptrdiff_t bounding_index )
    {
        import std.algorithm.searching;
        auto interval = Interval(bounding_index, -1);
        auto index = this.intervals.countUntil!(x => interval.end >= x.end);
        if (index >= 0)
            this.intervals = this.intervals[index + 1 .. $];
    }

    unittest
    {
        OrderedIntervals intervals;

        intervals.intervals = [ Interval(10, 20), Interval(30, 40) ];

        intervals.removeUntil(1);
        intervals.removeUntil(10);
        assert (intervals.intervals == [ Interval(10, 20), Interval(30, 40) ]);

        intervals.removeUntil(20);
        assert (intervals.intervals == [ Interval(30, 40) ]);

        intervals.removeUntil(39);
        assert (intervals.intervals == [ Interval(30, 40) ]);

        intervals.removeUntil(45);
        assert (intervals.intervals == [ ]);
    }
}

private bool isSubsetOf(Interval a, Interval b)
{
    return a.start >= b.start && a.end <= b.end;
}
