#ifndef GC_SLAB_H
#define GC_SLAB_H

#include <utility>  // std::is_pointer

#include "mycpp/common.h"  // DISALLOW_COPY_AND_ASSIGN
#include "mycpp/gc_obj.h"  // GC_OBJ

// Return the size of a resizeable allocation.  For now we just round up by
// powers of 2. This could be optimized later.  CPython has an interesting
// policy in listobject.c.
//
// https://stackoverflow.com/questions/466204/rounding-up-to-next-power-of-2
inline int RoundUp(int n) {
  // Note: List::RoundCapacity refines this.  TODO: remove this check when we
  // have Dict::RoundCapacity.
  if (n < 4) {
    return 4;
  }

  // TODO: what if int isn't 32 bits?
  n--;
  n |= n >> 1;
  n |= n >> 2;
  n |= n >> 4;
  n |= n >> 8;
  n |= n >> 16;
  n++;
  return n;
}

template <typename T>
class Slab {
  // Slabs of pointers are scanned; slabs of ints/bools are opaque.
 public:
  explicit Slab(unsigned num_items)
      : GC_SLAB(header_,
                std::is_pointer<T>() ? HeapTag::Scanned : HeapTag::Opaque,
                num_items) {
  }
  GC_OBJ(header_);
  T items_[1];  // variable length

  DISALLOW_COPY_AND_ASSIGN(Slab);
};

template <typename T, int N>
class GlobalSlab {
  // A template type with the same layout as Slab of length N.  For
  // initializing global constant List.
 public:
  ObjHeader header_;
  T items_[N];

  DISALLOW_COPY_AND_ASSIGN(GlobalSlab)
};

// The first field is items_
const int kSlabHeaderSize = offsetof(Slab<int>, items_);

#endif  // GC_SLAB_H
