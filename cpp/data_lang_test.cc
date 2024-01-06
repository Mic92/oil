#include "cpp/data_lang.h"

#include "vendor/greatest.h"

TEST part_is_utf8_test() {
  BigStr* s = StrFromC("hi");

  ASSERT(pyj8::PartIsUtf8(s, 0, 2));

  // empty string is trivially UTF-8
  ASSERT(pyj8::PartIsUtf8(s, 0, 0));

  BigStr* binary = StrFromC("h\xff");
  ASSERT(!pyj8::PartIsUtf8(binary, 0, len(binary)));

  // first byte is UTF-8
  ASSERT(pyj8::PartIsUtf8(binary, 0, 1));
  // second byte isn't
  ASSERT(!pyj8::PartIsUtf8(binary, 1, 2));

  PASS();
}

GREATEST_MAIN_DEFS();

int main(int argc, char** argv) {
  GREATEST_MAIN_BEGIN();

  RUN_TEST(part_is_utf8_test);

  GREATEST_MAIN_END();
  return 0;
}
