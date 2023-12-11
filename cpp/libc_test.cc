#include "cpp/libc.h"

#include <regex.h>  // regcomp()
#include <unistd.h>  // gethostname()

#include "mycpp/runtime.h"
#include "vendor/greatest.h"

TEST hostname_test() {
  BigStr* s0 = libc::gethostname();
  ASSERT(s0 != nullptr);

  char buf[1024];
  ASSERT(gethostname(buf, HOST_NAME_MAX) == 0);
  ASSERT(str_equals(s0, StrFromC(buf)));

  PASS();
}

TEST realpath_test() {
  BigStr* result = libc::realpath(StrFromC("/"));
  ASSERT(str_equals(StrFromC("/"), result));

  bool caught = false;
  try {
    libc::realpath(StrFromC("/nonexistent_ZZZ"));
  } catch (IOError_OSError* e) {
    caught = true;
  }
  ASSERT(caught);

  PASS();
}

TEST libc_test() {
  log("sizeof(wchar_t) = %d", sizeof(wchar_t));

  int width = 0;

  // TODO: enable this test.  Is it not picking LC_CTYPE?
  // Do we have to do some initialization like libc.cpython_reset_locale() ?
#if 0
  try {
    // mu character \u{03bc} in utf-8
    width = libc::wcswidth(StrFromC("\xce\xbc"));
  } catch (UnicodeError* e) {
    log("UnicodeError %s", e->message->data_);
  }
  ASSERT_EQ_FMT(2, width, "%d");
#endif

  width = libc::wcswidth(StrFromC("foo"));
  ASSERT_EQ(3, width);

  libc::print_time(0.1, 0.2, 0.3);

  BigStr* s1 = (StrFromC("foo.py "))->strip();
  ASSERT(libc::fnmatch(StrFromC("*.py"), s1));
  ASSERT(!libc::fnmatch(StrFromC("*.py"), StrFromC("foo.p")));

  // extended glob
  ASSERT(libc::fnmatch(StrFromC("*(foo|bar).py"), StrFromC("foo.py")));
  ASSERT(!libc::fnmatch(StrFromC("*(foo|bar).py"), StrFromC("foo.p")));

  List<BigStr*>* results =
      libc::regex_match(StrFromC("(a+).(a+)"), StrFromC("-abaacaaa"));
  ASSERT_EQ_FMT(3, len(results), "%d");
  ASSERT(str_equals(StrFromC("abaa"), results->at(0)));  // whole match
  ASSERT(str_equals(StrFromC("a"), results->at(1)));
  ASSERT(str_equals(StrFromC("aa"), results->at(2)));

  results = libc::regex_match(StrFromC("z+"), StrFromC("abaacaaa"));
  ASSERT_EQ(nullptr, results);

  Tuple2<int, int>* result;
  BigStr* s = StrFromC("oXooXoooXoX");
  result = libc::regex_first_group_match(StrFromC("(X.)"), s, 0);
  ASSERT_EQ_FMT(1, result->at0(), "%d");
  ASSERT_EQ_FMT(3, result->at1(), "%d");

  result = libc::regex_first_group_match(StrFromC("(X.)"), s, 3);
  ASSERT_EQ_FMT(4, result->at0(), "%d");
  ASSERT_EQ_FMT(6, result->at1(), "%d");

  result = libc::regex_first_group_match(StrFromC("(X.)"), s, 6);
  ASSERT_EQ_FMT(8, result->at0(), "%d");
  ASSERT_EQ_FMT(10, result->at1(), "%d");

  BigStr* h = libc::gethostname();
  log("gethostname() = %s %d", h->data_, len(h));

  PASS();
}

TEST libc_glob_test() {
  // This depends on the file system
  auto files = libc::glob(StrFromC("*.testdata"));
  // 3 files are made by the shell wrapper
  ASSERT_EQ_FMT(3, len(files), "%d");

  print(files->at(0));

  auto files2 = libc::glob(StrFromC("*.pyzzz"));
  ASSERT_EQ_FMT(0, len(files2), "%d");

  PASS();
}

TEST for_test_coverage() {
  // Sometimes we're not connected to a terminal
  try {
    libc::get_terminal_width();
  } catch (IOError_OSError* e) {
  }

  PASS();
}

TEST regexec_test() {
  regex_t pat;

  const char* unanchored = "[abc]([0-9]*)(x?)(y)-";
  const char* anchored = "^[abc]([0-9]*)(x?)(y)-";

  const char* p = unanchored;

  int cflags = REG_EXTENDED;
  if (regcomp(&pat, p, cflags) != 0) {
    FAIL();
  }
  int outlen = pat.re_nsub + 1;  // number of captures

  // TODO: Could statically allocate 99, and assert that re_nsub is less than
  // 99.  Would speed up loops.
  regmatch_t* pmatch =
      static_cast<regmatch_t*>(malloc(sizeof(regmatch_t) * outlen));

  // adjacent matches
  const char* s = "a345y-axy- there b789y- cy-";

  int cur_pos = 0;
  while (true) {
    // Necessary so ^ doesn't match in the middle!
    int eflags = cur_pos == 0 ? 0 : REG_NOTBOL;
    bool match = regexec(&pat, s + cur_pos, outlen, pmatch, eflags) == 0;

    if (!match) {
      break;
    }
    int i;
    for (i = 0; i < outlen; i++) {
      int start = pmatch[i].rm_so;
      int end = pmatch[i].rm_eo;
      int len = end - start;
      BigStr* m = StrFromC(s + cur_pos + start, len);
      log("%d GROUP %d (%d-%d) = [%s]", cur_pos, i, start, end, m->data_);
    }
    log("");
    cur_pos += pmatch[0].rm_eo;
  }

  free(pmatch);
  regfree(&pat);

  PASS();
}


GREATEST_MAIN_DEFS();

int main(int argc, char** argv) {
  gHeap.Init();

  GREATEST_MAIN_BEGIN();

  RUN_TEST(hostname_test);
  RUN_TEST(realpath_test);
  RUN_TEST(libc_test);
  RUN_TEST(libc_glob_test);
  RUN_TEST(for_test_coverage);
  RUN_TEST(regexec_test);

  gHeap.CleanProcessExit();

  GREATEST_MAIN_END();
  return 0;
}
